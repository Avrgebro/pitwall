import 'package:flutter/foundation.dart';

import 'webhook_auth.dart';

enum WebhookUrlProblem {
  /// Not a full URL with a scheme and host.
  incomplete,

  /// A scheme other than https or http.
  unsupportedScheme,
}

/// Why readings can't be sent to a webhook target.
@immutable
sealed class WebhookProblem {
  const WebhookProblem();
}

final class NoWebhookUrl extends WebhookProblem {
  const NoWebhookUrl();

  @override
  bool operator ==(Object other) => other is NoWebhookUrl;

  @override
  int get hashCode => (NoWebhookUrl).hashCode;
}

final class BadWebhookUrl extends WebhookProblem {
  const BadWebhookUrl(this.problem);

  final WebhookUrlProblem problem;

  @override
  bool operator ==(Object other) =>
      other is BadWebhookUrl && other.problem == problem;

  @override
  int get hashCode => problem.hashCode;
}

final class IncompleteWebhookAuth extends WebhookProblem {
  const IncompleteWebhookAuth(this.problem);

  final AuthProblem problem;

  @override
  bool operator ==(Object other) =>
      other is IncompleteWebhookAuth && other.problem == problem;

  @override
  int get hashCode => problem.hashCode;
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

  bool get _hasUrl => url.isNotEmpty;

  /// Why the URL can't be used, or null if it can or there's none.
  WebhookUrlProblem? get _urlProblem {
    if (!_hasUrl) return null;
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
  bool get isInsecure => urlUsable && Uri.parse(url).scheme == 'http';

  /// Why readings can't be sent here, or null if they can.
  WebhookProblem? get problem {
    if (!_hasUrl) return const NoWebhookUrl();
    if (_urlProblem case final problem?) return BadWebhookUrl(problem);
    if (auth.problem case final problem?) return IncompleteWebhookAuth(problem);
    return null;
  }

  bool get isUsable => problem == null;

  /// Whether it has a URL, usable or not.
  bool get hasUrl => problem is! NoWebhookUrl;

  /// Whether the URL can be used, whatever the credentials.
  bool get urlUsable => switch (problem) {
    NoWebhookUrl() || BadWebhookUrl() => false,
    IncompleteWebhookAuth() || null => true,
  };

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
