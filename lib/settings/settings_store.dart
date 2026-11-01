import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../profiles/signal_set.dart';
import '../vehicles/vehicle.dart';
import 'settings.dart';

/// Saves settings on the device: plain settings in shared preferences, the
/// webhook URL in secure storage (Android Keystore / iOS Keychain), and each
/// vehicle's imported profile as a file in the app's private storage.
class SettingsStore {
  SettingsStore({
    SharedPreferencesAsync? preferences,
    FlutterSecureStorage? secrets,
  }) : _preferences = preferences ?? SharedPreferencesAsync(),
       _secrets = secrets ?? const FlutterSecureStorage();

  static const _settingsKey = 'settings';
  static const _webhookUrlKey = 'webhook_url';

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

  Future<String?> loadWebhookUrl() => _secrets.read(key: _webhookUrlKey);

  Future<void> saveWebhookUrl(String? url) => url == null || url.isEmpty
      ? _secrets.delete(key: _webhookUrlKey)
      : _secrets.write(key: _webhookUrlKey, value: url);

  /// The vehicle's imported profile, or null if it has none.
  Future<SignalSet?> loadProfile(Vehicle vehicle) async {
    if (vehicle.profileName == null) return null;
    final file = await _profileFile(vehicle.id);
    if (!await file.exists()) return null;
    try {
      return SignalSet.parse(await file.readAsString());
    } on FormatException {
      return null;
    }
  }

  /// Saves an imported profile for [vehicle] and returns the vehicle with
  /// its profile name set; the caller saves the settings. [source] must
  /// already have parsed.
  Future<Vehicle> saveProfile(
    Vehicle vehicle,
    String source,
    String name,
  ) async {
    final file = await _profileFile(vehicle.id);
    await file.parent.create(recursive: true);
    await file.writeAsString(source, flush: true);
    return vehicle.copyWith(profileName: name);
  }

  /// Deletes the vehicle's profile and returns the vehicle without it.
  Future<Vehicle> deleteProfile(Vehicle vehicle) async {
    final file = await _profileFile(vehicle.id);
    if (await file.exists()) await file.delete();
    return vehicle.copyWith(profileName: null);
  }

  /// Moves the single-car profile file to the migrated vehicle and saves
  /// the settings in the new format.
  Future<AppSettings> _migrate(AppSettings settings) async {
    var vehicle = settings.vehicles.single;
    final legacy = File('${await _directory()}/$_legacyProfileFile');
    if (await legacy.exists()) {
      final name = await _preferences.getString(_legacyProfileNameKey);
      vehicle = await saveProfile(
        vehicle,
        await legacy.readAsString(),
        name ?? _legacyProfileFile,
      );
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
