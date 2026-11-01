import 'package:pitwall/profiles/signal_set.dart';
import 'package:pitwall/settings/settings.dart';
import 'package:pitwall/settings/settings_store.dart';

/// Keeps settings in memory instead of on the device.
class FakeSettingsStore implements SettingsStore {
  FakeSettingsStore({this.settings = const Settings()});

  Settings settings;
  String? webhookUrl;
  (String, String)? profile;

  @override
  Future<Settings> load() async => settings;

  @override
  Future<void> save(Settings settings) async => this.settings = settings;

  @override
  Future<String?> loadWebhookUrl() async => webhookUrl;

  @override
  Future<void> saveWebhookUrl(String? url) async => webhookUrl = url;

  @override
  Future<(SignalSet, String)?> loadProfile() async => switch (profile) {
    (final source, final name) => (SignalSet.parse(source), name),
    null => null,
  };

  @override
  Future<void> saveProfile(String source, String name) async =>
      profile = (source, name);

  @override
  Future<void> deleteProfile() async => profile = null;
}
