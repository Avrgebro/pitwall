import 'package:flutter/foundation.dart';

import 'webhook_target.dart';

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

/// How one send went: accepted, or why not.
@immutable
sealed class SendResult {
  const SendResult();
}

/// The server took it, with this 2xx status.
final class Accepted extends SendResult {
  const Accepted(this.statusCode);

  final int statusCode;

  @override
  bool operator ==(Object other) =>
      other is Accepted && other.statusCode == statusCode;

  @override
  int get hashCode => statusCode.hashCode;
}

/// Why a delivery failed. Descriptions for people are written by the UI;
/// nothing here contains the URL or credentials.
sealed class DeliveryError extends SendResult {
  const DeliveryError();

  /// What gets delivery going again. The sender retries only
  /// [DeliveryFix.retry].
  DeliveryFix get fix;
}

/// The webhook settings can't be used, so nothing was sent.
final class UnusableWebhook extends DeliveryError {
  const UnusableWebhook(this.problem);

  final WebhookProblem problem;

  @override
  DeliveryFix get fix => DeliveryFix.settings;

  @override
  bool operator ==(Object other) =>
      other is UnusableWebhook && other.problem == problem;

  @override
  int get hashCode => problem.hashCode;
}

/// What a rejection says, from its status.
enum RejectionReason {
  /// 401 or 403: this phone or its credentials are refused.
  notAllowed,

  /// 404, 405 or 410: the server takes no readings at this address, or no
  /// longer does.
  unknownWebhook,

  /// 3xx: the webhook moved. A POST isn't followed to its new address.
  moved,

  /// 400, 413 or 422: the server won't take that reading, however often
  /// it's sent. One is dropped, so the ones behind it still go; a second
  /// in a row is the server refusing them all, so delivery stops.
  refusedPayload,

  /// Anything else, which may pass.
  serverTrouble,
}

/// The saved webhook couldn't be read, as when Android's secure storage
/// fails, so nothing was sent. Entering it again replaces it.
final class UnreadableWebhook extends DeliveryError {
  const UnreadableWebhook();

  @override
  DeliveryFix get fix => DeliveryFix.settings;

  @override
  bool operator ==(Object other) => other is UnreadableWebhook;

  @override
  int get hashCode => (UnreadableWebhook).hashCode;
}

/// The server answered with an error status.
final class Rejected extends DeliveryError {
  const Rejected(this.statusCode);

  final int statusCode;

  /// The one place statuses are grouped: what to do and what to say both
  /// follow from it.
  RejectionReason get reason => switch (statusCode) {
    401 || 403 => RejectionReason.notAllowed,
    404 || 405 || 410 => RejectionReason.unknownWebhook,
    >= 300 && < 400 => RejectionReason.moved,
    400 || 413 || 422 => RejectionReason.refusedPayload,
    _ => RejectionReason.serverTrouble,
  };

  /// Only a change on the server or in the settings helps, unless it may
  /// pass on its own.
  @override
  DeliveryFix get fix => switch (reason) {
    RejectionReason.notAllowed ||
    RejectionReason.unknownWebhook ||
    RejectionReason.moved ||
    RejectionReason.refusedPayload => DeliveryFix.server,
    RejectionReason.serverTrouble => DeliveryFix.retry,
  };

  @override
  bool operator ==(Object other) =>
      other is Rejected && other.statusCode == statusCode;

  @override
  int get hashCode => statusCode.hashCode;
}

/// The server didn't answer in time.
final class TimedOut extends DeliveryError {
  const TimedOut();

  @override
  DeliveryFix get fix => DeliveryFix.retry;

  @override
  bool operator ==(Object other) => other is TimedOut;

  @override
  int get hashCode => (TimedOut).hashCode;
}

/// What kept the server from being reached, as far as the phone can tell.
enum NetworkFailure {
  /// The phone has no network, or no route to it.
  noNetwork,

  /// The webhook's host name didn't resolve.
  hostNotFound,

  /// Something answered at the address, but refused the connection.
  refused,

  /// The connection was cut, by the network or the server.
  reset,

  /// Connecting took too long.
  timedOut,

  /// The secure connection couldn't be set up, as with a bad certificate.
  secureConnection,

  /// Anything else.
  other;

  /// In a few words, for the log.
  String get label => switch (this) {
    noNetwork => 'no network',
    hostNotFound => 'host not found',
    refused => 'connection refused',
    reset => 'connection cut',
    timedOut => 'connecting timed out',
    secureConnection => 'secure connection failed',
    other => 'network error',
  };
}

/// The server couldn't be reached: no signal, wrong host, server down.
/// Only the [failure]'s kind is kept, never the error's text, which can
/// name the webhook's host.
final class Unreachable extends DeliveryError {
  const Unreachable([this.failure = NetworkFailure.other]);

  final NetworkFailure failure;

  @override
  DeliveryFix get fix => DeliveryFix.retry;

  @override
  bool operator ==(Object other) =>
      other is Unreachable && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}

/// How the attempts so far went. Only deliveries change it.
@immutable
class DeliveryOutcome {
  const DeliveryOutcome({
    this.failedAttempts = 0,
    this.lastSuccess,
    this.lastFailure,
    this.lastError,
    this.dropped = 0,
    this.lastRefusal,
  });

  /// Failed attempts since the last success.
  final int failedAttempts;
  final DateTime? lastSuccess;
  final DateTime? lastFailure;

  /// Why the last attempt failed, while that still stands: null after a
  /// success, and after a reading was dropped, as the server answered.
  final DeliveryError? lastError;

  /// Readings the server refused and that were dropped, so the ones
  /// behind them went, since the user last retried.
  final int dropped;

  /// The refusal that dropped the last of them.
  final Rejected? lastRefusal;

  DeliveryOutcome succeeded(DateTime at) => DeliveryOutcome(
    lastSuccess: at,
    lastFailure: lastFailure,
    dropped: dropped,
    lastRefusal: lastRefusal,
  );

  DeliveryOutcome failed(DeliveryError error, DateTime at) => DeliveryOutcome(
    failedAttempts: failedAttempts + 1,
    lastSuccess: lastSuccess,
    lastFailure: at,
    lastError: error,
    dropped: dropped,
    lastRefusal: lastRefusal,
  );

  /// A reading the server refused was dropped.
  DeliveryOutcome droppedOne(Rejected refusal, DateTime at) => DeliveryOutcome(
    failedAttempts: failedAttempts + 1,
    lastSuccess: lastSuccess,
    lastFailure: at,
    dropped: dropped + 1,
    lastRefusal: refusal,
  );

  /// As the user saw the drops, or retried: they're behind them.
  DeliveryOutcome get withoutDrops => DeliveryOutcome(
    failedAttempts: failedAttempts,
    lastSuccess: lastSuccess,
    lastFailure: lastFailure,
    lastError: lastError,
  );
}

/// How delivery is going, for the status shown to the user.
@immutable
class DeliveryStatus {
  const DeliveryStatus({
    this.queued = 0,
    this.deliveredThrough = 0,
    this.outcome = const DeliveryOutcome(),
  });

  /// Readings waiting to be delivered.
  final int queued;

  /// The newest reading delivered; see `WebhookSender.queue`. Readings go
  /// out in order, so every one before it has left the queue too: delivered,
  /// or dropped when the queue was full. Only the oldest are ever dropped,
  /// never the newest.
  final int deliveredThrough;

  final DeliveryOutcome outcome;
}

/// One send to the webhook: how it went, how long it took, and whether it
/// was a test. Every POST is one, for the developer log; a test send is
/// one too, unless the webhook can't be used, when nothing went out.
@immutable
class DeliveryAttempt {
  const DeliveryAttempt({
    required this.elapsed,
    required this.result,
    this.test = false,
  });

  final Duration elapsed;
  final SendResult result;
  final bool test;

  bool get succeeded => result is Accepted;
}
