import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'delivery_status.dart';
import 'delivery_storage.dart';
import 'payload.dart';
import 'webhook_auth.dart';

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

  /// The URL and credentials to send to, or null if none is set.
  final Future<WebhookTarget?> Function() _webhookTarget;
  final http.Client _client;
  final DateTime Function() _clock;
  final Duration Function(int attempt) _backoff;

  /// Called after every POST, for the developer log.
  final void Function(DeliveryAttempt attempt)? onAttempt;

  final status = ValueNotifier(const DeliveryStatus());

  List<String> _queue = [];
  int _seq = 0;
  String? _lastReading;
  int _failures = 0;
  bool _flushing = false;
  Timer? _retry;

  /// Loads what was left from earlier runs and starts delivering it.
  Future<void> init() async {
    final state = await _storage.load();
    _queue = [...state.queue];
    _seq = state.seq;
    _lastReading = state.lastReading;
    _update();
    unawaited(flush());
  }

  /// Queues a reading and tries to deliver everything queued.
  Future<void> send({
    required String device,
    required Map<String, double> values,
    required bool connected,
    bool? engineRunning,
  }) async {
    _seq++;
    final payload = jsonEncode(
      buildPayload(
        device: device,
        seq: _seq,
        timestamp: _clock(),
        values: values,
        connected: connected,
        engineRunning: engineRunning,
      ),
    );
    _queue.add(payload);
    if (values.isNotEmpty) _lastReading = payload;
    if (_queue.length > maxQueued) {
      _queue.removeRange(0, _queue.length - maxQueued);
    }
    await _persist();
    _update();
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
        if (target == null || target.url.isEmpty) {
          _fail(const DeliveryError(DeliveryErrorKind.noUrl));
          return;
        }
        if (target.auth.problem case final problem?) {
          _fail(
            DeliveryError(
              DeliveryErrorKind.authIncomplete,
              authProblem: problem,
            ),
          );
          return;
        }
        final (:error, :elapsed) = await _post(target, _queue.first);
        if (error != null) {
          _fail(error);
          return;
        }
        _queue.removeAt(0);
        _failures = 0;
        await _persist();
        _update(lastSuccess: _clock(), clearError: true);
      }
    } finally {
      _flushing = false;
    }
  }

  /// Sends a test payload straight to [target], without queueing it.
  Future<TestResult> sendTest(WebhookTarget target) async {
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
    } on FormatException {
      error = const DeliveryError(DeliveryErrorKind.invalidUrl);
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

  static DeliveryError? _errorFor(int statusCode) => switch (statusCode) {
    >= 200 && < 300 => null,
    401 ||
    403 => DeliveryError(DeliveryErrorKind.refused, statusCode: statusCode),
    404 => const DeliveryError(DeliveryErrorKind.notFound, statusCode: 404),
    _ => DeliveryError(DeliveryErrorKind.serverError, statusCode: statusCode),
  };

  void _fail(DeliveryError error) {
    _update(lastFailure: _clock(), error: error, failed: true);
    // Only the user can fix the rest; delivery resumes on the next send,
    // when the webhook settings change, or on Retry.
    if (!error.kind.retryable) return;
    _retry = Timer(_backoff(_failures++), () => unawaited(flush()));
  }

  Future<void> _persist() => _storage.save(
    DeliveryState(queue: List.of(_queue), seq: _seq, lastReading: _lastReading),
  );

  void _update({
    DateTime? lastSuccess,
    DateTime? lastFailure,
    DeliveryError? error,
    bool clearError = false,
    bool failed = false,
  }) {
    final current = status.value;
    status.value = DeliveryStatus(
      queued: _queue.length,
      failedAttempts: clearError
          ? 0
          : current.failedAttempts + (failed ? 1 : 0),
      lastSuccess: lastSuccess ?? current.lastSuccess,
      lastFailure: lastFailure ?? current.lastFailure,
      lastError: clearError ? null : (error ?? current.lastError),
      latest: _latest(),
    );
  }

  Reading? _latest() {
    final source = _lastReading;
    if (source == null) return null;
    try {
      final json = jsonDecode(source) as Map<String, Object?>;
      return Reading(
        device: json['device'] as String? ?? '',
        timestamp: DateTime.parse(json['timestamp'] as String),
        values: {
          for (final MapEntry(:key, :value)
              in (json['values'] as Map<String, Object?>? ?? const {}).entries)
            if (value is num) key: value,
        },
        // Payloads are unique (each has its own seq), so still being in the
        // queue means not delivered yet.
        delivered: !_queue.contains(source),
      );
    } on Object {
      return null;
    }
  }
}
