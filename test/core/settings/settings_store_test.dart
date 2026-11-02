import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/settings/settings_store.dart';
import 'package:pitwall/core/webhook/webhook_auth.dart';
import 'package:pitwall/core/webhook/webhook_target.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  test('a webhook saved under the earlier two keys moves to one', () async {
    FlutterSecureStorage.setMockInitialValues({
      'webhook_url': 'https://example.com/api/webhook/abc',
      'webhook_auth': '{"type":"bearer","token":"secret"}',
    });
    const secrets = FlutterSecureStorage();
    final store = SettingsStore(secrets: secrets);

    const expected = WebhookTarget(
      'https://example.com/api/webhook/abc',
      WebhookAuth(type: WebhookAuthType.bearer, token: 'secret'),
    );
    expect(await store.loadWebhook(), expected);
    expect(await secrets.read(key: 'webhook_url'), isNull);
    expect(await secrets.read(key: 'webhook_auth'), isNull);
    // Read back from the new key alone.
    expect(await SettingsStore(secrets: secrets).loadWebhook(), expected);
  });

  test('saving no webhook removes it', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const secrets = FlutterSecureStorage();
    final store = SettingsStore(secrets: secrets);

    await store.saveWebhook(const WebhookTarget('https://example.com/x'));
    expect(await secrets.read(key: 'webhook'), isNotNull);
    await store.saveWebhook(WebhookTarget.none);
    expect(await secrets.read(key: 'webhook'), isNull);
    expect(await store.loadWebhook(), WebhookTarget.none);
  });
}
