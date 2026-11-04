import '../../core/webhook/delivery_status.dart';
import '../../core/webhook/webhook_auth.dart';
import '../../core/webhook/webhook_target.dart';

/// Plain-language wording for delivery problems, shared by Home, Settings
/// and setup. Every state is a sentence; HTTP codes only appear in
/// brackets after the explanation.
abstract final class DeliveryText {
  /// A short headline and an explanation for [error].
  static ({String title, String message}) error(DeliveryError error) =>
      switch (error) {
        UnusableWebhook(problem: NoWebhookUrl()) => (
          title: 'No webhook set',
          message:
              'Readings stay on this phone until you add a webhook URL in '
              'Settings.',
        ),
        UnusableWebhook(problem: IncompleteWebhookAuth(:final problem)) => (
          title: 'Authentication isn\'t finished',
          message: authProblem(problem),
        ),
        UnusableWebhook(problem: BadWebhookUrl(:final problem)) => (
          title: 'The webhook URL isn\'t valid',
          message: urlProblem(problem),
        ),
        Rejected(reason: RejectionReason.unknownWebhook) => (
          title: 'The webhook doesn\'t exist',
          message:
              'The server doesn\'t know this webhook (HTTP 404). Check the '
              'URL in Settings.',
        ),
        Rejected(reason: RejectionReason.notAllowed, :final statusCode) => (
          title: 'The webhook is refusing readings',
          message:
              'The server says this phone isn\'t allowed to send '
              '(HTTP $statusCode). The URL or its token may have changed.',
        ),
        Rejected(reason: RejectionReason.serverTrouble, :final statusCode) => (
          title: 'The server is having trouble',
          message:
              'It answered with an error (HTTP $statusCode). Pitwall keeps '
              'trying.',
        ),
        TimedOut() => (
          title: 'The server is slow to answer',
          message: 'Pitwall keeps trying.',
        ),
        Unreachable() => (
          title: 'Couldn\'t reach the server',
          message:
              'Nothing answered at this address. Check that the server is '
              'running and the phone is online.',
        ),
      };

  static String authProblem(AuthProblem problem) => switch (problem) {
    AuthProblem.missingToken => 'Enter the token.',
    AuthProblem.tokenHasWhitespace =>
      'The token can\'t contain spaces or line breaks.',
    AuthProblem.missingUsername => 'Enter the username.',
    AuthProblem.usernameHasColon => 'The username can\'t contain ":".',
    AuthProblem.invalidHeaderName =>
      'Enter a header name, like X-API-Key, without spaces.',
    AuthProblem.reservedHeader =>
      'Pitwall sets this header itself; use another one.',
    AuthProblem.missingHeaderValue => 'Enter the header value.',
    AuthProblem.lineBreak => 'Credentials can\'t contain line breaks.',
  };

  static String urlProblem(WebhookUrlProblem problem) => switch (problem) {
    WebhookUrlProblem.incomplete =>
      'Enter a full URL, like https://example.com/api/webhook/…',
    WebhookUrlProblem.unsupportedScheme =>
      'The URL must start with https:// or http://',
  };

  static String authType(WebhookAuthType type) => switch (type) {
    WebhookAuthType.none => 'None',
    WebhookAuthType.bearer => 'Bearer token',
    WebhookAuthType.basic => 'Username and password',
    WebhookAuthType.header => 'Custom header',
  };
}
