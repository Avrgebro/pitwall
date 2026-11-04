import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../profiles/profile_ref.dart';
import '../profiles/signal_set.dart';
import '../profiles/stored_profile.dart';
import '../storage/app_files.dart';
import '../vehicles/vehicle.dart';
import '../webhook/webhook_target.dart';
import 'profile_files.dart';
import 'settings.dart';

export 'profile_files.dart';

/// A saved webhook that was read but can't be understood.
class UnreadableWebhookException implements Exception {
  const UnreadableWebhookException();

  @override
  String toString() => 'The saved webhook can\'t be read';
}

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
  ///
  /// As the store loads, once: a saved webhook that can't be understood is
  /// set aside, and, with settings that were read, profile files are put
  /// in order; see [ProfileFiles.tidy]. Neither can fail loading: what
  /// they couldn't do is reported, and left as it was.
  Future<AppSettings> load() async {
    final settings = await _loadSettings();
    await _reported('setting aside the saved webhook', _setAsideWebhook);
    // New settings name no files: none can be told unused.
    if (settings != null) {
      await _profiles.tidy(settings, report: _reported);
    }
    return settings ?? const AppSettings();
  }

  /// Runs [action], reporting a failure rather than throwing it.
  static Future<void> _reported(
    String what,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on Object catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'settings',
          context: ErrorDescription('while $what'),
        ),
      );
    }
  }

  Future<AppSettings?> _loadSettings() => _read(
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
  );

  Future<void> save(AppSettings settings) => _preferences.setString(
    _settingsKey,
    encodeVersioned(_settingsVersion, settings.toJson()),
  );

  /// The webhook URL and credentials; [WebhookTarget.none] if not set.
  ///
  /// Only reads, so it's safe however often deliveries ask, even while the
  /// user saves a new one. Throws [UnreadableWebhookException] if what's
  /// saved can't be understood, which [load] sets aside, and anything
  /// secure storage throws.
  Future<WebhookTarget> loadWebhook() async {
    final source = await _secrets.read(key: _webhookKey);
    if (source == null) return WebhookTarget.none;
    return decodeVersioned(source, _webhookReaders) ??
        (throw const UnreadableWebhookException());
  }

  static final VersionReaders<WebhookTarget> _webhookReaders = {
    0: WebhookTarget.fromJson,
    _webhookVersion: (json) => switch (dataOf(json)) {
      final data? => WebhookTarget.fromJson(data),
      null => null,
    },
  };

  /// Sets aside a saved webhook that can't be understood, as [_read] does
  /// with settings.
  Future<void> _setAsideWebhook() async {
    await _read(
      _webhookKey,
      from: (key) => _secrets.read(key: key),
      setAside: (key, value) => _secrets.write(key: key, value: value),
      remove: (key) => _secrets.delete(key: key),
      readers: _webhookReaders,
    );
  }

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
      // Under the time, so a copy set aside before is kept too.
      await setAside(
        '$key.unreadable.${DateTime.now().millisecondsSinceEpoch}',
        source,
      );
      await remove(key);
    }
    return value;
  }

  /// The vehicles' profile files; see [ProfileFiles].
  static const _profiles = ProfileFiles();

  Future<StoredProfile> loadProfile(Vehicle vehicle) => _profiles.load(vehicle);

  Future<void> saveProfile(
    String vehicleId,
    ProfileRef ref,
    SignalSet profile,
  ) => _profiles.save(vehicleId, ref, profile);

  Future<void> deleteProfile(String vehicleId, ProfileRef ref) =>
      _profiles.delete(vehicleId, ref);

  Future<void> deleteProfiles(String vehicleId) =>
      _profiles.deleteAll(vehicleId);
}
