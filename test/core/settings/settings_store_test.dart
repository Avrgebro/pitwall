import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/settings/settings.dart';
import 'package:pitwall/core/settings/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pitwall/core/webhook/webhook_target.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  test('settings saved before versions load as they are', () async {
    final preferences = SharedPreferencesAsync();
    await preferences.setString(
      'settings',
      '{"vehicles": [{"id": "a1", "name": "tucson"}], "setupDone": true}',
    );

    final settings = await SettingsStore(preferences: preferences).load();

    expect(settings.vehicles.single.name, 'tucson');
    expect(settings.setupDone, isTrue);
  });

  for (final (kind, saved) in [
    ('from a newer version', '{"version": 99, "setupDone": true}'),
    ('that aren\'t JSON', '{"setupDone": tru'),
  ]) {
    test('settings $kind are set aside before anything is saved', () async {
      final preferences = SharedPreferencesAsync();
      await preferences.setString('settings', saved);
      final store = SettingsStore(preferences: preferences);

      expect((await store.load()).setupDone, isFalse);
      await store.save(const AppSettings(setupDone: true));

      expect(await preferences.getString('settings.setAside'), saved);
    });
  }

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
