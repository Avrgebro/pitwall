import 'package:flutter/foundation.dart';

import 'webhook_auth.dart';

enum DeliveryErrorKind {
  /// No webhook URL is set.
  noUrl(retryable: false),

  /// Authentication is chosen but incomplete.
  authIncomplete(retryable: false),

  /// The URL can't be parsed.
  invalidUrl(retryable: false),

  /// HTTP 401 or 403: the server doesn't accept these credentials or URL.
  refused(retryable: false),

  /// HTTP 404: the server doesn't know this webhook.
  notFound(retryable: false),

  /// Any other non-2xx answer.
  serverError(retryable: true),

  /// The server didn't answer in time.
  timeout(retryable: true),

  /// The server couldn't be reached: no signal, wrong host, server down.
  unreachable(retryable: true);

  const DeliveryErrorKind({required this.retryable});

  /// Whether retrying later can help without the user changing anything.
  /// The sender retries only these; the rest wait for the user.
  final bool retryable;
}

/// Why a delivery failed. Descriptions for people are written by the UI;
/// nothing here contains the URL or credentials.
@immutable
class DeliveryError {
  const DeliveryError(this.kind, {this.statusCode, this.authProblem});

  final DeliveryErrorKind kind;

  /// The HTTP status, for errors the server answered with.
  final int? statusCode;

  /// For [DeliveryErrorKind.authIncomplete], what's wrong.
  final AuthProblem? authProblem;

  /// Whether retrying later can help without the user changing anything.
  bool get isTransient => kind.retryable;

  @override
  bool operator ==(Object other) =>
      other is DeliveryError &&
      other.kind == kind &&
      other.statusCode == statusCode &&
      other.authProblem == authProblem;

  @override
  int get hashCode => Object.hash(kind, statusCode, authProblem);
}

/// How delivery is going, for the status shown to the user.
@immutable
class DeliveryStatus {
  const DeliveryStatus({
    this.queued = 0,
    this.failedAttempts = 0,
    this.lastSuccess,
    this.lastFailure,
    this.lastError,
    this.deliveredThrough = 0,
  });

  /// Readings waiting to be delivered.
  final int queued;

  /// Failed attempts since the last success.
  final int failedAttempts;
  final DateTime? lastSuccess;
  final DateTime? lastFailure;

  /// Why the last attempt failed. Null after a success.
  final DeliveryError? lastError;

  /// Every reading up to this sequence number is delivered; see
  /// `WebhookSender.queue`.
  final int deliveredThrough;
}

/// One POST to the webhook, for the developer log.
@immutable
class DeliveryAttempt {
  const DeliveryAttempt({
    required this.elapsed,
    this.statusCode,
    this.error,
    this.test = false,
  });

  final Duration elapsed;
  final int? statusCode;
  final DeliveryError? error;
  final bool test;
}

/// The outcome of a test send.
@immutable
class TestResult {
  const TestResult({required this.elapsed, this.error});

  final Duration elapsed;
  final DeliveryError? error;

  bool get succeeded => error == null;
}
