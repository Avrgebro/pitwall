import 'dart:convert';

enum WebhookAuthType {
  /// No credentials. Right for Home Assistant, where the webhook id in the
  /// URL is the secret.
  none,

  /// `Authorization: Bearer <token>`.
  bearer,

  /// `Authorization: Basic <base64 of username:password>`.
  basic,

  /// Any one header, such as `X-API-Key: <key>`.
  header,
}

/// Credentials added to every webhook request. Kept in secure storage with
/// the URL, and never shown in errors or logs.
class WebhookAuth {
  const WebhookAuth({
    this.type = WebhookAuthType.none,
    this.token = '',
    this.username = '',
    this.password = '',
    this.headerName = '',
    this.headerValue = '',
  });

  static const none = WebhookAuth();

  // Header names are HTTP "tokens" (RFC 9110).
  static final _headerName = RegExp(r"^[!#$%&'*+\-.^_`|~0-9A-Za-z]+$");

  // Line breaks or other control characters would let a value add headers.
  static final _controlCharacter = RegExp(r'[\x00-\x1F\x7F]');

  // Headers the app sets itself.
  static const _reservedHeaders = {'content-type', 'content-length', 'host'};

  final WebhookAuthType type;
  final String token;
  final String username;
  final String password;
  final String headerName;
  final String headerValue;

  /// The headers to add to each request.
  Map<String, String> get headers => switch (type) {
    WebhookAuthType.none => const {},
    WebhookAuthType.bearer => {'Authorization': 'Bearer $token'},
    WebhookAuthType.basic => {
      'Authorization':
          'Basic ${base64Encode(utf8.encode('$username:$password'))}',
    },
    WebhookAuthType.header => {headerName: headerValue},
  };

  /// Why these credentials can't be used, or null if they can.
  String? get problem => switch (type) {
    WebhookAuthType.none => null,
    WebhookAuthType.bearer when token.isEmpty => 'Enter the token.',
    WebhookAuthType.bearer when token.contains(RegExp(r'\s')) =>
      'The token can\'t contain spaces or line breaks.',
    WebhookAuthType.basic when username.isEmpty => 'Enter the username.',
    WebhookAuthType.basic when username.contains(':') =>
      'The username can\'t contain ":".',
    WebhookAuthType.basic
        when _controlCharacter.hasMatch(username + password) =>
      'The username and password can\'t contain line breaks.',
    WebhookAuthType.header when !_headerName.hasMatch(headerName) =>
      'Enter a header name, like X-API-Key, without spaces.',
    WebhookAuthType.header
        when _reservedHeaders.contains(headerName.toLowerCase()) =>
      'Pitwall sets $headerName itself; use another header.',
    WebhookAuthType.header when headerValue.isEmpty =>
      'Enter the header value.',
    WebhookAuthType.header when _controlCharacter.hasMatch(headerValue) =>
      'The header value can\'t contain line breaks.',
    _ => null,
  };

  WebhookAuth copyWith({
    WebhookAuthType? type,
    String? token,
    String? username,
    String? password,
    String? headerName,
    String? headerValue,
  }) => WebhookAuth(
    type: type ?? this.type,
    token: token ?? this.token,
    username: username ?? this.username,
    password: password ?? this.password,
    headerName: headerName ?? this.headerName,
    headerValue: headerValue ?? this.headerValue,
  );

  Map<String, Object?> toJson() => {
    'type': type.name,
    'token': token,
    'username': username,
    'password': password,
    'headerName': headerName,
    'headerValue': headerValue,
  };

  factory WebhookAuth.fromJson(Map<String, Object?> json) {
    String text(String key) => switch (json[key]) {
      final String value => value,
      _ => '',
    };
    return WebhookAuth(
      type:
          WebhookAuthType.values.asNameMap()[json['type']] ??
          WebhookAuthType.none,
      token: text('token'),
      username: text('username'),
      password: text('password'),
      headerName: text('headerName'),
      headerValue: text('headerValue'),
    );
  }
}

/// Where readings go: the webhook URL and its credentials.
class WebhookTarget {
  const WebhookTarget(this.url, [this.auth = WebhookAuth.none]);

  final String url;
  final WebhookAuth auth;
}
