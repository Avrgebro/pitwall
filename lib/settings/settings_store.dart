import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../profiles/signal_set.dart';
import 'settings.dart';

/// Saves settings on the device: plain settings in shared preferences, the
/// webhook URL in secure storage (Android Keystore / iOS Keychain), and the
/// imported vehicle profile as a file in the app's private storage.
class SettingsStore {
  SettingsStore({
    SharedPreferencesAsync? preferences,
    FlutterSecureStorage? secrets,
  }) : _preferences = preferences ?? SharedPreferencesAsync(),
       _secrets = secrets ?? const FlutterSecureStorage();

  static const _settingsKey = 'settings';
  static const _webhookUrlKey = 'webhook_url';
  static const _profileFileName = 'vehicle_profile.json';
  static const _profileNameKey = 'profile_name';

  final SharedPreferencesAsync _preferences;
  final FlutterSecureStorage _secrets;

  Future<Settings> load() async {
    final saved = await _preferences.getString(_settingsKey);
    if (saved == null) return const Settings();
    try {
      return Settings.fromJson(jsonDecode(saved) as Map<String, Object?>);
    } on Object {
      // Unreadable settings shouldn't lock the user out; start fresh.
      return const Settings();
    }
  }

  Future<void> save(Settings settings) =>
      _preferences.setString(_settingsKey, jsonEncode(settings.toJson()));

  Future<String?> loadWebhookUrl() => _secrets.read(key: _webhookUrlKey);

  Future<void> saveWebhookUrl(String? url) => url == null || url.isEmpty
      ? _secrets.delete(key: _webhookUrlKey)
      : _secrets.write(key: _webhookUrlKey, value: url);

  /// The imported profile and the file name it was imported from, or null.
  Future<(SignalSet, String)?> loadProfile() async {
    final file = await _profileFile();
    if (!await file.exists()) return null;
    try {
      final profile = SignalSet.parse(await file.readAsString());
      final name = await _preferences.getString(_profileNameKey);
      return (profile, name ?? _profileFileName);
    } on FormatException {
      return null;
    }
  }

  /// Saves an imported profile. [source] must already have parsed.
  Future<void> saveProfile(String source, String name) async {
    await (await _profileFile()).writeAsString(source, flush: true);
    await _preferences.setString(_profileNameKey, name);
  }

  Future<void> deleteProfile() async {
    final file = await _profileFile();
    if (await file.exists()) await file.delete();
    await _preferences.remove(_profileNameKey);
  }

  Future<File> _profileFile() async => File(
    '${(await getApplicationSupportDirectory()).path}/$_profileFileName',
  );
}
