import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../obd/trouble_codes.dart';
import 'delivery_status.dart';
import 'delivery_storage.dart';
import 'payload.dart';
import 'queued_reading.dart';
import 'webhook_target.dart';

/// Sends readings to the webhook, one POST each, in order. Readings are
/// queued on the device first, so nothing is lost without signal; failed
/// sends are retried with backoff.
///
/// Errors never carry the URL or credentials, which work like passwords.
class WebhookSender {
  WebhookSender({
    required this._storage,
    required this._webhookTarget,
    http.Client? client,
    DateTime Function()? clock,
    Duration Function(int attempt)? backoff,
    this.onAttempt,
    this.onDropped,
  }) : _client = client ?? http.Client(),
       _clock = clock ?? DateTime.now,
       _backoff = backoff ?? defaultBackoff;

  /// Oldest readings are dropped beyond this, so a long outage can't fill
  /// the phone. At one reading a minute that's about three days of driving.
  static const maxQueued = 5000;
  static const timeout = Duration(seconds: 15);

  /// 5 s, 10 s, 20 s... up to 5 minutes.
  static Duration defaultBackoff(int attempt) =>
      Duration(seconds: min(5 * pow(2, attempt).toInt(), 300));

  final DeliveryStorage _storage;

  /// The URL and credentials to send to, as saved now.
  final Future<WebhookTarget> Function() _webhookTarget;
  final http.Client _client;
  final DateTime Function() _clock;
  final Duration Function(int attempt) _backoff;

  /// Called after every POST, for the developer log.
  final void Function(DeliveryAttempt attempt)? onAttempt;

  /// Called when the server refused a reading for what it holds, and it
  /// was dropped, for the developer log. Only one in a row is dropped;
  /// see [RejectionReason.refusedPayload].
  final void Function(QueuedReading reading, DeliveryAttempt attempt)?
  onDropped;

  final status = ValueNotifier(const DeliveryStatus());

  /// How the attempts so far went, which only deliveries change.
  DeliveryOutcome _outcome = const DeliveryOutcome();

  /// Oldest first; sequence numbers only go up.
  List<QueuedReading> _queue = [];
  int _seq = 0;
  int _deliveredThrough = 0;

  /// The delivery under way, if one is.
  Future<void>? _flushing;

  /// Set by [dispose]: a delivery under way stops at its next step.
  bool _disposed = false;
  Timer? _retry;

  /// Whether the delivery state may be saved: not when it couldn't be
  /// loaded, so a file that's there but unreadable isn't written over.
  bool _saves = true;

  /// Loads what was left from earlier runs and starts delivering it. Never
  /// throws: if the saved state can't be read, readings are kept in memory
  /// only, and the failure is reported.
  Future<void> init() async {
    final DeliveryState state;
    try {
      state = await _storage.load() ?? DeliveryState.afterLoss(_clock());
    } on Object catch (error, stack) {
      _saves = false;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'delivery',
          context: ErrorDescription('while loading the delivery queue'),
        ),
      );
      return _start(DeliveryState.afterLoss(_clock()));
    }
    _start(state);
  }

  void _start(DeliveryState state) {
    _queue = [...state.queue];
    _seq = state.seq;
    _deliveredThrough = state.deliveredThrough;
    _publish();
    unawaited(flush());
  }

  /// Queues a reading and starts delivering what's queued, without waiting
  /// for it; [flush] waits. Returns the reading's sequence number: it's
  /// delivered once the status's `deliveredThrough` reaches it.
  ///
  /// Numbers come from the clock, in milliseconds, and are always above
  /// the one before: they only ever go up for the receiver, across
  /// restarts and even after the saved state was lost.
  Future<int> queue({
    required String device,
    required Map<String, double> values,
    required bool connected,
    bool? engineRunning,
    TroubleCodes? troubleCodes,
  }) async {
    _seq = max(_seq + 1, _clock().millisecondsSinceEpoch);
    final reading = QueuedReading(
      seq: _seq,
      device: device,
      timestamp: _clock(),
      values: values,
      connected: connected,
      engineRunning: engineRunning,
      troubleCodes: troubleCodes,
    );
    _queue.add(reading);
    if (_queue.length > maxQueued) {
      _queue.removeRange(0, _queue.length - maxQueued);
    }
    await _persist();
    _publish();
    // Waiting for the user, readings only queue up.
    if (!_waitingForFix) unawaited(flush());
    return reading.seq;
  }

  /// Whether the last failure needs the user, on the server or in the
  /// settings: nothing is sent until they [retry].
  bool _waitingForFix = false;

  /// Delivers queued readings, oldest first, until the queue is empty or a
  /// send fails, and completes then. A delivery already under way is the
  /// one waited for: it takes in readings queued meanwhile. After a failure
  /// that retrying can fix, a retry is scheduled; after one only the user
  /// can fix, nothing is sent until [retry]. See [DeliveryError.fix].
  Future<void> flush() async {
    if (_waitingForFix) return;
    await (_flushing ??= _deliver().whenComplete(() => _flushing = null));
  }

  /// Delivers queued readings again, as after the user fixed what stopped
  /// them: from the Retry button, or a change in the webhook settings.
  Future<void> retry() {
    _waitingForFix = false;
    _outcome = _outcome.withoutDrops;
    _publish();
    return flush();
  }

  /// The user saw which readings were dropped: they're no longer shown.
  void dismissDrops() {
    _outcome = _outcome.withoutDrops;
    _publish();
  }

  /// Whether the last reading the server answered was refused for what it
  /// holds. A refusal after one, and the server refuses them all.
  bool _refusedLast = false;

  Future<void> _deliver() async {
    _retry?.cancel();
    while (_queue.isNotEmpty) {
      final WebhookTarget target;
      try {
        target = await _webhookTarget();
      } on Object {
        // Only the user can fix it, by entering the webhook again.
        if (_disposed) return;
        _failed(const UnreadableWebhook());
        return;
      }
      if (_disposed) return;
      if (_unusable(target) case final error?) {
        _failed(error);
        return;
      }
      // Kept, as a full queue can drop it from the front while it's posted.
      final sent = _queue.first;
      final attempt = await _post(target, jsonEncode(sent.toPayload()));
      if (_disposed) return;
      // The server won't take this reading however often it's sent: it's
      // dropped, so the ones behind it still go. Refused again, it's the
      // server, and the reading stays, as below, until the user retries.
      if (attempt.result case final Rejected refusal
          when refusal.reason == RejectionReason.refusedPayload &&
              !_refusedLast) {
        _refusedLast = true;
        _queue.remove(sent);
        await _persist();
        if (_disposed) return;
        _outcome = _outcome.droppedOne(refusal, _clock());
        onDropped?.call(sent, attempt);
        _publish();
        continue;
      }
      // The reading stays queued; the next run delivers it.
      if (attempt.result case final DeliveryError error) {
        _failed(error);
        return;
      }
      _refusedLast = false;
      _queue.remove(sent);
      _deliveredThrough = max(_deliveredThrough, sent.seq);
      await _persist();
      _succeeded();
    }
  }

  /// Sends a test payload straight to [target], without queueing it.
  Future<DeliveryAttempt> sendTest(WebhookTarget target) async {
    if (_unusable(target) case final error?) {
      return DeliveryAttempt(elapsed: Duration.zero, result: error, test: true);
    }
    return _post(
      target,
      jsonEncode({
        ...buildPayload(
          device: 'pitwall-test',
          seq: 0,
          timestamp: _clock(),
          values: const {},
          connected: false,
        ),
        'test': true,
      }),
      test: true,
    );
  }

  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _client.close();
    status.dispose();
  }

  Future<DeliveryAttempt> _post(
    WebhookTarget target,
    String body, {
    bool test = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    SendResult result;
    try {
      final response = await _client
          .post(
            Uri.parse(target.url),
            headers: {
              ...target.auth.headers,
              'Content-Type': 'application/json',
            },
            body: body,
          )
          .timeout(timeout);
      result = switch (response.statusCode) {
        final status when status >= 200 && status < 300 => Accepted(status),
        final status => Rejected(status),
      };
    } on TimeoutException {
      result = const TimedOut();
    } on Exception {
      // Network errors can mention the URL, so only the kind is kept.
      result = const Unreachable();
    }
    stopwatch.stop();
    final attempt = DeliveryAttempt(
      elapsed: stopwatch.elapsed,
      result: result,
      test: test,
    );
    onAttempt?.call(attempt);
    return attempt;
  }

  /// Why [target] can't be sent to, as [WebhookTarget.problem] decides.
  static DeliveryError? _unusable(WebhookTarget target) =>
      switch (target.problem) {
        final problem? => UnusableWebhook(problem),
        null => null,
      };

  void _succeeded() {
    _outcome = _outcome.succeeded(_clock());
    _publish();
  }

  void _failed(DeliveryError error) {
    _outcome = _outcome.failed(error, _clock());
    _publish();
    // Only the user can fix the rest: delivery resumes when the webhook
    // settings change, or on Retry, not with every reading.
    if (error.fix != DeliveryFix.retry) {
      _waitingForFix = true;
      return;
    }
    _retry = Timer(
      _backoff(_outcome.failedAttempts - 1),
      () => unawaited(flush()),
    );
  }

  /// Shows the queue and the last delivery outcome as they are now.
  void _publish() {
    if (_disposed) return;
    status.value = DeliveryStatus(
      queued: _queue.length,
      deliveredThrough: _deliveredThrough,
      outcome: _outcome,
    );
  }

  Future<void> _persist() async {
    if (!_saves) return;
    await _storage.save(
      DeliveryState(
        queue: List.of(_queue),
        seq: _seq,
        deliveredThrough: _deliveredThrough,
      ),
    );
  }
}
