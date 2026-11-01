import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'delivery_storage.dart';
import 'payload.dart';
import 'webhook_auth.dart';

/// How delivery is going, for the status shown to the user.
@immutable
class DeliveryStatus {
  const DeliveryStatus({
    this.queued = 0,
    this.lastSuccess,
    this.lastFailure,
    this.lastError,
  });

  /// Readings waiting to be delivered.
  final int queued;
  final DateTime? lastSuccess;
  final DateTime? lastFailure;

  /// Why the last attempt failed, in plain words. Null after a success.
  final String? lastError;
}

/// Sends readings to the webhook, one POST each, in order. Readings are
/// queued on the device first, so nothing is lost without signal; failed
/// sends are retried with backoff.
///
/// Error messages never include the URL or credentials, which work like
/// passwords.
class WebhookSender {
  WebhookSender({
    required this._storage,
    required this._webhookTarget,
    http.Client? client,
    DateTime Function()? clock,
    Duration Function(int attempt)? backoff,
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

  final status = ValueNotifier(const DeliveryStatus());

  List<String> _queue = [];
  int _seq = 0;
  int _failures = 0;
  bool _flushing = false;
  Timer? _retry;

  /// Loads what was left from earlier runs and starts delivering it.
  Future<void> init() async {
    final state = await _storage.load();
    _queue = [...state.queue];
    _seq = state.seq;
    _update();
    unawaited(flush());
  }

  /// Queues a reading and tries to deliver everything queued.
  Future<void> send({
    required String device,
    required Map<String, double> values,
    required bool connected,
  }) async {
    _seq++;
    _queue.add(
      jsonEncode(
        buildPayload(
          device: device,
          seq: _seq,
          timestamp: _clock(),
          values: values,
          connected: connected,
        ),
      ),
    );
    if (_queue.length > maxQueued) {
      _queue.removeRange(0, _queue.length - maxQueued);
    }
    await _persist();
    _update();
    await flush();
  }

  /// Delivers queued readings, oldest first, until the queue is empty or a
  /// send fails. After a failure, a retry is scheduled.
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    _retry?.cancel();
    try {
      while (_queue.isNotEmpty) {
        final target = await _webhookTarget();
        if (target == null || target.url.isEmpty) {
          _fail('No webhook URL is set.', retry: false);
          return;
        }
        if (target.auth.problem case final problem?) {
          _fail('Authentication isn\'t set up: $problem', retry: false);
          return;
        }
        final error = await _post(target, _queue.first);
        if (error != null) {
          _fail(error, retry: true);
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
  /// Returns null on success, or what went wrong in plain words.
  Future<String?> sendTest(WebhookTarget target) => _post(
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
  );

  void dispose() {
    _retry?.cancel();
    _client.close();
    status.dispose();
  }

  Future<String?> _post(WebhookTarget target, String body) async {
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
      if (response.statusCode >= 200 && response.statusCode < 300) return null;
      return switch (response.statusCode) {
        401 || 403 =>
          'The server refused the request (HTTP '
              '${response.statusCode}). Check the URL and authentication.',
        404 =>
          'The server doesn\'t know this webhook (HTTP 404). '
              'Check the webhook URL.',
        final code => 'The server answered with an error (HTTP $code).',
      };
    } on TimeoutException {
      return 'The server took too long to answer.';
    } on FormatException {
      return 'The webhook URL isn\'t valid.';
    } on Exception {
      // Network errors can mention the URL, so their text isn't shown.
      return 'Couldn\'t reach the server. No signal?';
    }
  }

  void _fail(String error, {required bool retry}) {
    _update(lastFailure: _clock(), error: error);
    if (!retry) return;
    _retry = Timer(_backoff(_failures++), () => unawaited(flush()));
  }

  Future<void> _persist() =>
      _storage.save(DeliveryState(queue: List.of(_queue), seq: _seq));

  void _update({
    DateTime? lastSuccess,
    DateTime? lastFailure,
    String? error,
    bool clearError = false,
  }) {
    final current = status.value;
    status.value = DeliveryStatus(
      queued: _queue.length,
      lastSuccess: lastSuccess ?? current.lastSuccess,
      lastFailure: lastFailure ?? current.lastFailure,
      lastError: clearError ? null : (error ?? current.lastError),
    );
  }
}
