import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../profiles/profile_ref.dart';
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
  Future<AppSettings> load() async {
    final settings = await _loadSettings();
    await _moveProfileFiles(settings);
    return settings;
  }

  /// Before each import had a file of its own, a vehicle's profile was in
  /// one file named after it. Each moves, once, to the name its settings
  /// now give it; see [profileFileName].
  Future<void> _moveProfileFiles(AppSettings settings) async {
    for (final vehicle in settings.vehicles) {
      final ref = vehicle.profile;
      if (ref == null || ref.importedAt == null) continue;
      final legacy = await appFile('profiles/${vehicle.id}.json');
      final named = await appFile(profileFileName(vehicle.id, ref));
      if (!await legacy.exists() || await named.exists()) continue;
      await named.parent.create(recursive: true);
      await legacy.rename(named.path);
    }
  }

  Future<AppSettings> _loadSettings() async =>
      await _read(
        _settingsKey,
        from: _preferences.getString,
        setAside: _preferences.setString,
        remove: _preferences.remove,
        readers: {
          // Version 1 kept the fields next to the version, and before
          // versions they were alone; both read the same.
          0: AppSettings.fromJson,
          1: AppSettings.fromJson,
          _settingsVersion: (json) => switch (dataOf(json)) {
            final data? => AppSettings.fromJson(data),
            null => null,
          },
        },
      ) ??
      const AppSettings();

  Future<void> save(AppSettings settings) => _preferences.setString(
    _settingsKey,
    encodeVersioned(_settingsVersion, settings.toJson()),
  );

  /// The webhook URL and credentials; [WebhookTarget.none] if not set, or
  /// not readable. Throws if they can't be read at all; see [_read].
  Future<WebhookTarget> loadWebhook() async =>
      await _read(
        _webhookKey,
        from: (key) => _secrets.read(key: key),
        setAside: (key, value) => _secrets.write(key: key, value: value),
        remove: (key) => _secrets.delete(key: key),
        readers: {
          0: WebhookTarget.fromJson,
          _webhookVersion: (json) => switch (dataOf(json)) {
            final data? => WebhookTarget.fromJson(data),
            null => null,
          },
        },
      ) ??
      WebhookTarget.none;

  Future<void> saveWebhook(WebhookTarget target) => target == WebhookTarget.none
      ? _secrets.delete(key: _webhookKey)
      : _secrets.write(
          key: _webhookKey,
          value: encodeVersioned(_webhookVersion, target.toJson()),
        );

  /// What's saved under [key], read by [decodeVersioned], or null if
  /// there's nothing. What was read but can't be understood is moved to
  /// its own key first, as a file is renamed, and is then nothing too.
  ///
  /// Throws if it can't be read, or can't be moved: then it's left as it
  /// is, and whoever loads it mustn't save over it.
  static Future<T?> _read<T>(
    String key, {
    required Future<String?> Function(String key) from,
    required Future<void> Function(String key, String value) setAside,
    required Future<void> Function(String key) remove,
    required VersionReaders<T> readers,
  }) async {
    final source = await from(key);
    if (source == null) return null;
    final value = decodeVersioned(source, readers);
    if (value == null) {
      await setAside('$key.unreadable', source);
      await remove(key);
    }
    return value;
  }

  /// The vehicle's imported profile, as found on the phone. A file that's
  /// gone, can't be read, or no longer parses is an [UnreadableProfile].
  Future<StoredProfile> loadProfile(Vehicle vehicle) async {
    final ref = vehicle.profile;
    if (ref == null) return const NoProfile();
    try {
      final file = await appFile(profileFileName(vehicle.id, ref));
      return LoadedProfile(ref, SignalSet.parse(await file.readAsString()));
    } on FileSystemException {
      return UnreadableProfile(ref);
    } on FormatException {
      return UnreadableProfile(ref);
    }
  }

  /// Saves [profile] as the file [ref] names for the vehicle. Only a
  /// parsed profile can be saved, so the file always holds one.
  Future<void> saveProfile(
    String vehicleId,
    ProfileRef ref,
    SignalSet profile,
  ) async {
    final file = await appFile(profileFileName(vehicleId, ref));
    await file.parent.create(recursive: true);
    await writeAtomically(file, profile.source);
  }

  /// Deletes the file [ref] names for the vehicle, if it's there.
  Future<void> deleteProfile(String vehicleId, ProfileRef ref) async {
    final file = await appFile(profileFileName(vehicleId, ref));
    if (await file.exists()) await file.delete();
  }

  /// Deletes every profile file the vehicle has.
  Future<void> deleteProfiles(String vehicleId) async {
    final legacy = await appFile('profiles/$vehicleId.json');
    if (await legacy.exists()) await legacy.delete();
    final folder = Directory((await appFile('profiles/$vehicleId')).path);
    if (await folder.exists()) await folder.delete(recursive: true);
  }

  /// Where the profile [ref] names is kept: a file per import, so the
  /// settings always name exactly the file they mean, and the one they
  /// named before is still there until they're saved. A profile from
  /// before import times were kept has the vehicle's one file.
  static String profileFileName(String vehicleId, ProfileRef ref) =>
      switch (ref.importedAt) {
        final at? =>
          'profiles/$vehicleId/${at.toUtc().microsecondsSinceEpoch}.json',
        null => 'profiles/$vehicleId.json',
      };
}
