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
        UnreadableWebhook() => (
          title: 'The webhook can\'t be read',
          message:
              'This phone couldn\'t read the saved webhook. Enter it again in '
              'Settings; readings stay on this phone until then.',
        ),
        UnusableWebhook(problem: IncompleteWebhookAuth(:final problem)) => (
          title: 'Authentication isn\'t finished',
          message: authProblem(problem),
        ),
        UnusableWebhook(problem: BadWebhookUrl(:final problem)) => (
          title: 'The webhook URL isn\'t valid',
          message: urlProblem(problem),
        ),
        Rejected(reason: RejectionReason.unknownWebhook, :final statusCode) => (
          title: 'The webhook isn\'t there',
          message:
              'The server takes no readings at this address '
              '(HTTP $statusCode). Check the URL in Settings.',
        ),
        Rejected(reason: RejectionReason.moved, :final statusCode) => (
          title: 'The webhook has moved',
          message:
              'The server points somewhere else (HTTP $statusCode). Enter the '
              'new address in Settings; https:// instead of http:// is a '
              'common cause.',
        ),
        Rejected(reason: RejectionReason.refusedPayload, :final statusCode) => (
          title: 'The server refused a reading',
          message:
              'It wouldn\'t take what Pitwall sent (HTTP $statusCode), so '
              'that reading was dropped; the rest still go. Check how the '
              'webhook is set up on the server.',
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
