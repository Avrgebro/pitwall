import 'package:flutter/foundation.dart';

import 'webhook_auth.dart';

enum WebhookUrlProblem {
  /// Not a full URL with a scheme and host.
  incomplete,

  /// A scheme other than https or http.
  unsupportedScheme,
}

/// Why readings can't be sent to a webhook target.
sealed class WebhookProblem {
  const WebhookProblem();
}

final class NoWebhookUrl extends WebhookProblem {
  const NoWebhookUrl();
}

final class BadWebhookUrl extends WebhookProblem {
  const BadWebhookUrl(this.problem);

  final WebhookUrlProblem problem;
}

final class IncompleteWebhookAuth extends WebhookProblem {
  const IncompleteWebhookAuth(this.problem);

  final AuthProblem problem;
}

/// Where readings go: the webhook URL and its credentials. Kept together in
/// secure storage, and checked here, the one place that decides whether
/// they can be used.
@immutable
class WebhookTarget {
  const WebhookTarget(this.url, [this.auth = WebhookAuth.none]);

  static const none = WebhookTarget('');

  final String url;
  final WebhookAuth auth;

  bool get hasUrl => url.isNotEmpty;

  /// Why the URL can't be used, or null if it can or there's none.
  WebhookUrlProblem? get urlProblem {
    if (!hasUrl) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return WebhookUrlProblem.incomplete;
    }
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      return WebhookUrlProblem.unsupportedScheme;
    }
    return null;
  }

  /// Plain http: readings, and any credentials, travel unencrypted.
  bool get isInsecure => urlProblem == null && Uri.parse(url).scheme == 'http';

  /// Why readings can't be sent here, or null if they can.
  WebhookProblem? get problem {
    if (!hasUrl) return const NoWebhookUrl();
    if (urlProblem case final problem?) return BadWebhookUrl(problem);
    if (auth.problem case final problem?) return IncompleteWebhookAuth(problem);
    return null;
  }

  bool get isUsable => problem == null;

  WebhookTarget copyWith({String? url, WebhookAuth? auth}) =>
      WebhookTarget(url ?? this.url, auth ?? this.auth);

  Map<String, Object?> toJson() => {'url': url, 'auth': auth.toJson()};

  factory WebhookTarget.fromJson(Map<String, Object?> json) => WebhookTarget(
    switch (json['url']) {
      final String url => url,
      _ => '',
    },
    switch (json['auth']) {
      final Map<String, Object?> auth => WebhookAuth.fromJson(auth),
      _ => WebhookAuth.none,
    },
  );

  @override
  bool operator ==(Object other) =>
      other is WebhookTarget && other.url == url && other.auth == auth;

  @override
  int get hashCode => Object.hash(url, auth);
}
