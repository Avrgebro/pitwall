import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/webhook/webhook_auth.dart';

void main() {
  group('headers', () {
    test('none adds nothing', () {
      expect(WebhookAuth.none.headers, isEmpty);
    });

    test('bearer token', () {
      const auth = WebhookAuth(type: WebhookAuthType.bearer, token: 'abc123');

      expect(auth.headers, {'Authorization': 'Bearer abc123'});
    });

    test('username and password', () {
      const auth = WebhookAuth(
        type: WebhookAuthType.basic,
        username: 'pitwall',
        password: 's3cret',
      );

      // base64("pitwall:s3cret")
      expect(auth.headers, {'Authorization': 'Basic cGl0d2FsbDpzM2NyZXQ='});
    });

    test('custom header', () {
      const auth = WebhookAuth(
        type: WebhookAuthType.header,
        headerName: 'X-API-Key',
        headerValue: 'key-1',
      );

      expect(auth.headers, {'X-API-Key': 'key-1'});
    });
  });

  group('problems', () {
    test('complete credentials have none', () {
      expect(WebhookAuth.none.problem, isNull);
      expect(
        const WebhookAuth(type: WebhookAuthType.bearer, token: 't').problem,
        isNull,
      );
    });

    test('missing parts are reported', () {
      expect(
        const WebhookAuth(type: WebhookAuthType.bearer).problem,
        isNotNull,
      );
      expect(const WebhookAuth(type: WebhookAuthType.basic).problem, isNotNull);
      expect(
        const WebhookAuth(
          type: WebhookAuthType.header,
          headerName: 'X-API-Key',
        ).problem,
        isNotNull,
      );
    });

    test('values that could add headers are refused', () {
      expect(
        const WebhookAuth(
          type: WebhookAuthType.header,
          headerName: 'X-API-Key',
          headerValue: 'key\r\nX-Other: injected',
        ).problem,
        isNotNull,
      );
      expect(
        const WebhookAuth(
          type: WebhookAuthType.bearer,
          token: 'abc\ndef',
        ).problem,
        isNotNull,
      );
      expect(
        const WebhookAuth(
          type: WebhookAuthType.header,
          headerName: 'Bad Name',
          headerValue: 'x',
        ).problem,
        isNotNull,
      );
    });

    test('headers the app sets itself are refused', () {
      expect(
        const WebhookAuth(
          type: WebhookAuthType.header,
          headerName: 'Content-Type',
          headerValue: 'text/plain',
        ).problem,
        isNotNull,
      );
    });

    test('a colon in the username is refused', () {
      expect(
        const WebhookAuth(type: WebhookAuthType.basic, username: 'a:b').problem,
        isNotNull,
      );
    });
  });

  test('credentials survive a round trip through JSON', () {
    const auth = WebhookAuth(
      type: WebhookAuthType.header,
      headerName: 'X-API-Key',
      headerValue: 'key-1',
    );

    final restored = WebhookAuth.fromJson(auth.toJson());

    expect(restored.type, WebhookAuthType.header);
    expect(restored.headers, {'X-API-Key': 'key-1'});
  });

  test('unknown saved types fall back to none', () {
    expect(WebhookAuth.fromJson({'type': 'oauth'}).type, WebhookAuthType.none);
  });
}
