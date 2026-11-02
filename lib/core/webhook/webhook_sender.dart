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

  /// Oldest first; sequence numbers only go up.
  List<QueuedReading> _queue = [];
  int _seq = 0;
  QueuedReading? _latest;
  bool _flushing = false;
  Timer? _retry;

  /// Loads what was left from earlier runs and starts delivering it.
  Future<void> init() async {
    final state = await _storage.load();
    _queue = [...state.queue];
    _seq = state.seq;
    _latest = state.latest;
    _queueChanged();
    unawaited(flush());
  }

  /// Queues a reading and tries to deliver everything queued.
  Future<void> send({
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
    if (values.isNotEmpty) _latest = reading;
    if (_queue.length > maxQueued) {
      _queue.removeRange(0, _queue.length - maxQueued);
    }
    await _persist();
    _queueChanged();
    await flush();
  }

  /// Delivers queued readings, oldest first, until the queue is empty or a
  /// send fails. After a failure that retrying can fix, a retry is
  /// scheduled; see [DeliveryErrorKind.retryable].
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    _retry?.cancel();
    try {
      while (_queue.isNotEmpty) {
        final target = await _webhookTarget();
        if (_unusable(target) case final error?) {
          _failed(error);
          return;
        }
        final (:error, :elapsed) = await _post(
          target,
          jsonEncode(_queue.first.toJson()),
        );
        if (error != null) {
          _failed(error);
          return;
        }
        _queue.removeAt(0);
        await _persist();
        _succeeded();
      }
    } finally {
      _flushing = false;
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
      error = const DeliveryError(DeliveryErrorKind.timeout);
    } on Exception {
      // Network errors can mention the URL, so only the kind is kept.
      error = const DeliveryError(DeliveryErrorKind.unreachable);
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

  /// Why [target] can't be sent to, as [WebhookTarget] decides, or null.
  static DeliveryError? _unusable(WebhookTarget target) {
    if (!target.hasUrl) return const DeliveryError(DeliveryErrorKind.noUrl);
    if (target.urlProblem != null) {
      return const DeliveryError(DeliveryErrorKind.invalidUrl);
    }
    if (target.auth.problem case final problem?) {
      return DeliveryError(
        DeliveryErrorKind.authIncomplete,
        authProblem: problem,
      );
    }
    return null;
  }

  static DeliveryError? _errorFor(int statusCode) => switch (statusCode) {
    >= 200 && < 300 => null,
    401 ||
    403 => DeliveryError(DeliveryErrorKind.refused, statusCode: statusCode),
    404 => const DeliveryError(DeliveryErrorKind.notFound, statusCode: 404),
    _ => DeliveryError(DeliveryErrorKind.serverError, statusCode: statusCode),
  };

  void _succeeded() {
    final current = status.value;
    _publish(
      failedAttempts: 0,
      lastSuccess: _clock(),
      lastFailure: current.lastFailure,
      lastError: null,
    );
  }

  void _failed(DeliveryError error) {
    final current = status.value;
    final attempts = current.failedAttempts + 1;
    _publish(
      failedAttempts: attempts,
      lastSuccess: current.lastSuccess,
      lastFailure: _clock(),
      lastError: error,
    );
    // Only the user can fix the rest; delivery resumes on the next send,
    // when the webhook settings change, or on Retry.
    if (!error.kind.retryable) return;
    _retry = Timer(_backoff(attempts - 1), () => unawaited(flush()));
  }

  /// The queue or the latest reading changed; delivery itself didn't.
  void _queueChanged() {
    final current = status.value;
    _publish(
      failedAttempts: current.failedAttempts,
      lastSuccess: current.lastSuccess,
      lastFailure: current.lastFailure,
      lastError: current.lastError,
    );
  }

  void _publish({
    required int failedAttempts,
    required DateTime? lastSuccess,
    required DateTime? lastFailure,
    required DeliveryError? lastError,
  }) {
    final latest = _latest;
    status.value = DeliveryStatus(
      queued: _queue.length,
      failedAttempts: failedAttempts,
      lastSuccess: lastSuccess,
      lastFailure: lastFailure,
      lastError: lastError,
      latest: latest == null
          ? null
          : Reading(
              device: latest.device,
              timestamp: latest.timestamp,
              values: latest.values,
              // The queue is in sequence order, so the reading is
              // delivered once everything left came after it.
              delivered: _queue.isEmpty || _queue.first.seq > latest.seq,
            ),
    );
  }

  Future<void> _persist() => _storage.save(
    DeliveryState(queue: List.of(_queue), seq: _seq, latest: _latest),
  );
}
