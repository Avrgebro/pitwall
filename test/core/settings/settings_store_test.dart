import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pitwall/core/profiles/stored_profile.dart';
import 'package:pitwall/core/settings/settings.dart';
import 'package:pitwall/core/settings/settings_store.dart';
import 'package:pitwall/core/vehicles/vehicle.dart';
import 'package:pitwall/core/webhook/webhook_target.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../profiles/test_profile.dart';

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
      // Moved, not copied, as a file is renamed: the next start doesn't
      // set it aside again.
      expect(await preferences.getString('settings'), isNull);
      await store.save(const AppSettings(setupDone: true));

      expect(await preferences.getString('settings.unreadable'), saved);
    });
  }

  test('settings and the webhook load back as saved', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = SettingsStore();
    const settings = AppSettings(
      vehicles: [Vehicle(id: 'a1', name: 'Tucson')],
      setupDone: true,
    );

    await store.save(settings);
    await store.saveWebhook(const WebhookTarget('https://example.com/x'));

    expect((await store.load()).vehicles.single.name, 'Tucson');
    expect(
      await store.loadWebhook(),
      const WebhookTarget('https://example.com/x'),
    );
  });

  test('settings saved with the version beside them still load', () async {
    final preferences = SharedPreferencesAsync();
    await preferences.setString(
      'settings',
      '{"version": 1, "vehicles": [{"id": "a1", "name": "tucson"}]}',
    );

    final settings = await SettingsStore(preferences: preferences).load();

    expect(settings.vehicles.single.name, 'tucson');
  });

  test('a webhook saved before versions still loads', () async {
    FlutterSecureStorage.setMockInitialValues({
      'webhook': '{"url": "https://example.com/x"}',
    });

    expect(
      await SettingsStore().loadWebhook(),
      const WebhookTarget('https://example.com/x'),
    );
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

  test('a profile kept in its vehicle\'s one file moves to its own', () async {
    final directory = Directory.systemTemp.createTempSync('pitwall');
    addTearDown(() => directory.deleteSync(recursive: true));
    PathProviderPlatform.instance = _TemporaryAppFiles(directory);
    File('${directory.path}/profiles/a1.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(testProfileJson);
    final preferences = SharedPreferencesAsync();
    await preferences.setString(
      'settings',
      '{"version": 2, "data": {"vehicles": [{"id": "a1", "name": "Tucson", '
          '"profileName": "default.json", '
          '"profileImportedAt": "2026-11-01T10:00:00.000Z"}]}}',
    );
    final store = SettingsStore(preferences: preferences);

    final vehicle = (await store.load()).vehicles.single;

    expect(await store.loadProfile(vehicle), isA<LoadedProfile>());
    expect(File('${directory.path}/profiles/a1.json').existsSync(), isFalse);
  });
}

/// The app's private storage, in a temporary directory.
class _TemporaryAppFiles extends PathProviderPlatform {
  _TemporaryAppFiles(this.directory);

  final Directory directory;

  @override
  Future<String?> getApplicationSupportPath() async => directory.path;
}
