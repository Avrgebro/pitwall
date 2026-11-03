import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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

  /// Loads what was left from earlier runs and starts delivering it.
  Future<void> init() async {
    final state = await _storage.load();
    _queue = [...state.queue];
    _seq = state.seq;
    _deliveredThrough = state.deliveredThrough;
    _publish();
    unawaited(flush());
  }

  /// Queues a reading and starts delivering what's queued, without waiting
  /// for it; [flush] waits. Returns the reading's sequence number: it's
  /// delivered once the status's `deliveredThrough` reaches it.
  Future<int> queue({
    required String device,
    required Map<String, double> values,
    required bool connected,
    bool? engineRunning,
  }) async {
    final reading = QueuedReading(
      seq: ++_seq,
      device: device,
      timestamp: _clock(),
      values: values,
      connected: connected,
      engineRunning: engineRunning,
    );
    _queue.add(reading);
    if (_queue.length > maxQueued) {
      _queue.removeRange(0, _queue.length - maxQueued);
    }
    await _persist();
    _publish();
    unawaited(flush());
    return reading.seq;
  }

  /// Delivers queued readings, oldest first, until the queue is empty or a
  /// send fails, and completes then. A delivery already under way is the
  /// one waited for: it takes in readings queued meanwhile. After a failure
  /// that retrying can fix, a retry is scheduled; see
  /// [DeliveryError.fix].
  Future<void> flush() =>
      _flushing ??= _deliver().whenComplete(() => _flushing = null);

  Future<void> _deliver() async {
    _retry?.cancel();
    while (_queue.isNotEmpty) {
      final target = await _webhookTarget();
      if (_disposed) return;
      if (_unusable(target) case final error?) {
        _failed(error);
        return;
      }
      // Kept, as a full queue can drop it from the front while it's posted.
      final sent = _queue.first;
      final (:error, :elapsed) = await _post(target, jsonEncode(sent.toJson()));
      // The reading stays queued; the next run delivers it.
      if (_disposed) return;
      if (error != null) {
        _failed(error);
        return;
      }
      _queue.remove(sent);
      _deliveredThrough = max(_deliveredThrough, sent.seq);
      await _persist();
      _succeeded();
    }
  }

  /// Sends a test payload straight to [target], without queueing it.
  Future<TestResult> sendTest(WebhookTarget target) async {
    if (_unusable(target) case final error?) {
      return TestResult(elapsed: Duration.zero, error: error);
    }
    final (:error, :elapsed) = await _post(
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
    return TestResult(elapsed: elapsed, error: error);
  }

  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _client.close();
    status.dispose();
  }

  Future<({DeliveryError? error, Duration elapsed})> _post(
    WebhookTarget target,
    String body, {
    bool test = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    int? statusCode;
    DeliveryError? error;
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
      statusCode = response.statusCode;
      error = _errorFor(response.statusCode);
    } on TimeoutException {
      error = const TimedOut();
    } on Exception {
      // Network errors can mention the URL, so only the kind is kept.
      error = const Unreachable();
    }
    stopwatch.stop();
    onAttempt?.call(
      DeliveryAttempt(
        elapsed: stopwatch.elapsed,
        statusCode: statusCode,
        error: error,
        test: test,
      ),
    );
    return (error: error, elapsed: stopwatch.elapsed);
  }

  /// Why [target] can't be sent to, as [WebhookTarget.problem] decides.
  static DeliveryError? _unusable(WebhookTarget target) =>
      switch (target.problem) {
        final problem? => UnusableWebhook(problem),
        null => null,
      };

  static DeliveryError? _errorFor(int statusCode) => switch (statusCode) {
    >= 200 && < 300 => null,
    _ => Rejected(statusCode),
  };

  void _succeeded() {
    _outcome = _outcome.succeeded(_clock());
    _publish();
  }

  void _failed(DeliveryError error) {
    _outcome = _outcome.failed(error, _clock());
    _publish();
    // Only the user can fix the rest; delivery resumes on the next send,
    // when the webhook settings change, or on Retry.
    if (error.fix != DeliveryFix.retry) return;
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

  Future<void> _persist() => _storage.save(
    DeliveryState(
      queue: List.of(_queue),
      seq: _seq,
      deliveredThrough: _deliveredThrough,
    ),
  );
}
