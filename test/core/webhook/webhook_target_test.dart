import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/webhook/webhook_auth.dart';
import 'package:pitwall/core/webhook/webhook_target.dart';

void main() {
  test('accepts https and http URLs', () {
    expect(
      const WebhookTarget('https://example.com/api/webhook/abc').urlProblem,
      isNull,
    );
    expect(
      const WebhookTarget('http://192.168.1.10:8123/x').urlProblem,
      isNull,
    );
  });

  test('rejects anything else', () {
    expect(
      const WebhookTarget('example.com/hook').urlProblem,
      WebhookUrlProblem.incomplete,
    );
    expect(
      const WebhookTarget('ftp://example.com/hook').urlProblem,
      WebhookUrlProblem.unsupportedScheme,
    );
  });

  test('no URL is not a problem with the URL, but not usable', () {
    expect(WebhookTarget.none.urlProblem, isNull);
    expect(WebhookTarget.none.isUsable, isFalse);
  });

  test('plain http is flagged as unencrypted', () {
    expect(const WebhookTarget('http://192.168.1.10/x').isInsecure, isTrue);
    expect(const WebhookTarget('HTTP://192.168.1.10/x').isInsecure, isTrue);
    expect(const WebhookTarget('https://example.com/x').isInsecure, isFalse);
  });

  test('usable needs a valid URL and complete credentials', () {
    const url = 'https://example.com/x';
    expect(const WebhookTarget(url).isUsable, isTrue);
    expect(
      const WebhookTarget(
        url,
        WebhookAuth(type: WebhookAuthType.bearer),
      ).isUsable,
      isFalse,
    );
  });

  test('a round trip through JSON keeps the URL and credentials', () {
    const target = WebhookTarget(
      'https://example.com/x',
      WebhookAuth(type: WebhookAuthType.bearer, token: 'abc'),
    );
    expect(WebhookTarget.fromJson(target.toJson()), target);
  });

  test('the problem says why it can\'t be sent to, first one first', () {
    expect(WebhookTarget.none.problem, isA<NoWebhookUrl>());
    expect(
      const WebhookTarget('example.com/hook').problem,
      isA<BadWebhookUrl>().having(
        (p) => p.problem,
        'problem',
        WebhookUrlProblem.incomplete,
      ),
    );
    expect(
      const WebhookTarget(
        'https://example.com/x',
        WebhookAuth(type: WebhookAuthType.bearer),
      ).problem,
      isA<IncompleteWebhookAuth>(),
    );
    expect(const WebhookTarget('https://example.com/x').problem, isNull);
  });
}
