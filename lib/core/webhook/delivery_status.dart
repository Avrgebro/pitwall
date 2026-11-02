import 'package:flutter/foundation.dart';

import 'webhook_auth.dart';

/// What gets a failed delivery going again.
enum DeliveryFix {
  /// Nothing: retrying later helps, and the sender retries on its own.
  retry,

  /// Only a change in the webhook settings.
  settings,

  /// A change on the server, such as in Home Assistant, or in the settings
  /// to match it; Retry helps once it's made.
  server,
}

enum DeliveryErrorKind {
  /// No webhook URL is set.
  noUrl(DeliveryFix.settings),

  /// Authentication is chosen but incomplete.
  authIncomplete(DeliveryFix.settings),

  /// The URL can't be parsed.
  invalidUrl(DeliveryFix.settings),

  /// HTTP 401 or 403: the server doesn't accept these credentials or URL.
  refused(DeliveryFix.server),

  /// HTTP 404: the server doesn't know this webhook.
  notFound(DeliveryFix.server),

  /// Any other non-2xx answer.
  serverError(DeliveryFix.retry),

  /// The server didn't answer in time.
  timeout(DeliveryFix.retry),

  /// The server couldn't be reached: no signal, wrong host, server down.
  unreachable(DeliveryFix.retry);

  const DeliveryErrorKind(this.fix);

  final DeliveryFix fix;

  /// Whether retrying later can help without the user changing anything.
  /// The sender retries only these.
  bool get retryable => fix == DeliveryFix.retry;

  /// Whether the user has to change something, in Settings or on the
  /// server.
  bool get needsUser => !retryable;
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
