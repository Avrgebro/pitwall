import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../profiles/signal_set.dart';
import '../storage/app_files.dart';
import '../vehicles/vehicle.dart';
import '../webhook/webhook_auth.dart';
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

  // Earlier versions kept the URL and credentials under two keys.
  static const _oldWebhookUrlKey = 'webhook_url';
  static const _oldWebhookAuthKey = 'webhook_auth';

  // Single-car format, before vehicles: one profile file and its name.
  static const _legacyProfileFile = 'vehicle_profile.json';
  static const _legacyProfileNameKey = 'profile_name';

  final SharedPreferencesAsync _preferences;
  final FlutterSecureStorage _secrets;

  Future<AppSettings> load() async {
    final saved = await _preferences.getString(_settingsKey);
    if (saved == null) return const AppSettings();
    final Map<String, Object?> json;
    try {
      json = jsonDecode(saved) as Map<String, Object?>;
    } on Object {
      // Unreadable settings shouldn't lock the user out; start fresh.
      return const AppSettings();
    }
    final settings = AppSettings.fromJson(json);
    if (AppSettings.isLegacy(json)) return _migrate(settings);
    return settings;
  }

  Future<void> save(AppSettings settings) =>
      _preferences.setString(_settingsKey, jsonEncode(settings.toJson()));

  /// The webhook URL and credentials; [WebhookTarget.none] if not set.
  Future<WebhookTarget> loadWebhook() async {
    final saved = await _secrets.read(key: _webhookKey);
    if (saved == null) return _migrateWebhook();
    return switch (_decode(saved)) {
      final Map<String, Object?> json => WebhookTarget.fromJson(json),
      _ => WebhookTarget.none,
    };
  }

  Future<void> saveWebhook(WebhookTarget target) => target == WebhookTarget.none
      ? _secrets.delete(key: _webhookKey)
      : _secrets.write(key: _webhookKey, value: jsonEncode(target.toJson()));

  /// Moves a URL and credentials saved under the earlier two keys into one.
  Future<WebhookTarget> _migrateWebhook() async {
    final url = await _secrets.read(key: _oldWebhookUrlKey);
    final auth = await _secrets.read(key: _oldWebhookAuthKey);
    if (url == null && auth == null) return WebhookTarget.none;
    final target = WebhookTarget(url ?? '', switch (_decode(auth)) {
      final Map<String, Object?> json => WebhookAuth.fromJson(json),
      _ => WebhookAuth.none,
    });
    await saveWebhook(target);
    await _secrets.delete(key: _oldWebhookUrlKey);
    await _secrets.delete(key: _oldWebhookAuthKey);
    return target;
  }

  /// [source] as JSON, or null if there's none or it doesn't parse.
  static Object? _decode(String? source) {
    if (source == null) return null;
    try {
      return jsonDecode(source);
    } on FormatException {
      return null;
    }
  }

  /// The vehicle's imported profile, or null if it has none.
  ///
  /// Throws [ProfileUnreadableException] if the vehicle has a profile but
  /// its file is gone or no longer parses.
  Future<SignalSet?> loadProfile(Vehicle vehicle) async {
    if (vehicle.profileName == null) return null;
    final file = await _profileFile(vehicle.id);
    if (!await file.exists()) throw const ProfileUnreadableException();
    try {
      return SignalSet.parse(await file.readAsString());
    } on FormatException {
      throw const ProfileUnreadableException();
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

  /// Moves the single-car profile file to the migrated vehicle and saves
  /// the settings in the new format.
  Future<AppSettings> _migrate(AppSettings settings) async {
    var vehicle = settings.vehicles.single;
    final legacy = File('${await _directory()}/$_legacyProfileFile');
    if (await legacy.exists()) {
      final name = await _preferences.getString(_legacyProfileNameKey);
      try {
        await saveProfile(
          vehicle.id,
          SignalSet.parse(await legacy.readAsString()),
        );
        vehicle = vehicle.copyWith(
          profileName: name ?? _legacyProfileFile,
          profileImportedAt: DateTime.now(),
        );
      } on FormatException {
        // A profile that no longer parses isn't carried over.
      }
      await legacy.delete();
      await _preferences.remove(_legacyProfileNameKey);
    }
    final migrated = settings.withVehicle(vehicle);
    await save(migrated);
    return migrated;
  }

  Future<File> _profileFile(String vehicleId) async =>
      File('${await _directory()}/profiles/$vehicleId.json');

  Future<String> _directory() async =>
      (await getApplicationSupportDirectory()).path;
}

/// The vehicle has a profile, but its file is gone or no longer parses.
class ProfileUnreadableException implements Exception {
  const ProfileUnreadableException();
}
