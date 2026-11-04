import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../profiles/signal_set.dart';
import '../profiles/stored_profile.dart';
import '../storage/app_files.dart';
import '../vehicles/vehicle.dart';
import '../webhook/webhook_target.dart';
import 'settings.dart';

/// Saves settings on the device: plain settings in shared preferences, the
/// webhook URL and credentials in secure storage (Android Keystore / iOS
/// Keychain), and each
/// vehicle's imported profile as a file in the app's private storage.
class SettingsStore {
  SettingsStore({
    SharedPreferencesAsync? preferences,
    FlutterSecureStorage? secrets,
  }) : _preferences = preferences ?? SharedPreferencesAsync(),
       _secrets = secrets ?? const FlutterSecureStorage();

  static const _settingsKey = 'settings';
  static const _webhookKey = 'webhook';

  /// The formats [save] and [saveWebhook] write.
  static const _settingsVersion = 2;
  static const _webhookVersion = 1;

  final SharedPreferencesAsync _preferences;
  final FlutterSecureStorage _secrets;

  /// The saved settings, or new ones if there are none, or none readable.
  /// Throws if they can't be read at all; see [_read].
  Future<AppSettings> load() async => switch (await _read(
    _settingsKey,
    from: _preferences.getString,
    setAside: _preferences.setString,
    remove: _preferences.remove,
    readers: {_settingsVersion: _settings},
    // Version 1 kept the fields next to the version, and before versions
    // they were alone; both read the same.
    before: {0: AppSettings.fromJson, 1: AppSettings.fromJson},
  )) {
    SavedData(:final value) => value,
    NothingSaved() || UnreadableData() => const AppSettings(),
  };

  static AppSettings? _settings(Object? data) => switch (data) {
    final Map<String, Object?> json => AppSettings.fromJson(json),
    _ => null,
  };

  Future<void> save(AppSettings settings) => _preferences.setString(
    _settingsKey,
    encodeVersioned(_settingsVersion, settings.toJson()),
  );

  /// The webhook URL and credentials; [WebhookTarget.none] if not set, or
  /// not readable. Throws if they can't be read at all; see [_read].
  Future<WebhookTarget> loadWebhook() async => switch (await _read(
    _webhookKey,
    from: (key) => _secrets.read(key: key),
    setAside: (key, value) => _secrets.write(key: key, value: value),
    remove: (key) => _secrets.delete(key: key),
    readers: {_webhookVersion: _webhook},
    before: {0: WebhookTarget.fromJson},
  )) {
    SavedData(:final value) => value,
    NothingSaved() || UnreadableData() => WebhookTarget.none,
  };

  static WebhookTarget? _webhook(Object? data) => switch (data) {
    final Map<String, Object?> json => WebhookTarget.fromJson(json),
    _ => null,
  };

  Future<void> saveWebhook(WebhookTarget target) => target == WebhookTarget.none
      ? _secrets.delete(key: _webhookKey)
      : _secrets.write(
          key: _webhookKey,
          value: encodeVersioned(_webhookVersion, target.toJson()),
        );

  /// What's saved under [key], read by [readVersioned]. What was read but
  /// can't be understood is moved to its own key first, as
  /// [UnreadableData] says, the same as a file is renamed.
  ///
  /// Throws if it can't be read, or can't be moved: then it's left as it
  /// is, and whoever loads it mustn't save over it.
  static Future<Saved<T>> _read<T>(
    String key, {
    required Future<String?> Function(String key) from,
    required Future<void> Function(String key, String value) setAside,
    required Future<void> Function(String key) remove,
    required Map<int, T? Function(Object? data)> readers,
    required Map<int, T? Function(Map<String, Object?> json)> before,
  }) async {
    final source = await from(key);
    final saved = readVersioned(source, readers: readers, before: before);
    if ((saved, source) case (UnreadableData(), final source?)) {
      await setAside('$key.unreadable', source);
      await remove(key);
    }
    return saved;
  }

  /// The vehicle's imported profile, as found on the phone. A file that's
  /// gone, can't be read, or no longer parses is an [UnreadableProfile].
  Future<StoredProfile> loadProfile(Vehicle vehicle) async {
    final ref = vehicle.profile;
    if (ref == null) return const NoProfile();
    try {
      final file = await _profileFile(vehicle.id);
      return LoadedProfile(ref, SignalSet.parse(await file.readAsString()));
    } on FileSystemException {
      return UnreadableProfile(ref);
    } on FormatException {
      return UnreadableProfile(ref);
    }
  }

  /// Saves [profile] as the vehicle's profile file. Only a parsed profile
  /// can be saved, so the file always holds one.
  Future<void> saveProfile(String vehicleId, SignalSet profile) async {
    final file = await _profileFile(vehicleId);
    await file.parent.create(recursive: true);
    await writeAtomically(file, profile.source);
  }

  Future<void> deleteProfile(String vehicleId) async {
    final file = await _profileFile(vehicleId);
    if (await file.exists()) await file.delete();
  }

  Future<File> _profileFile(String vehicleId) =>
      appFile('profiles/$vehicleId.json');
}
