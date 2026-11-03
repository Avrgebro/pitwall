import 'dart:convert';
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

  /// The format [save] writes. Earlier formats are brought up to date in
  /// [load], and only there; none needs it yet.
  static const _version = 1;

  final SharedPreferencesAsync _preferences;
  final FlutterSecureStorage _secrets;

  Future<AppSettings> load() async {
    final saved = await _preferences.getString(_settingsKey);
    if (saved == null) return const AppSettings();
    return switch (_decode(saved)) {
      // Before versions, settings were saved in this same shape.
      final Map<String, Object?> json
          when (json['version'] ?? _version) == _version =>
        AppSettings.fromJson(json),
      // Unreadable settings shouldn't lock the user out; start fresh.
      _ => const AppSettings(),
    };
  }

  Future<void> save(AppSettings settings) => _preferences.setString(
    _settingsKey,
    jsonEncode({'version': _version, ...settings.toJson()}),
  );

  /// The webhook URL and credentials; [WebhookTarget.none] if not set.
  Future<WebhookTarget> loadWebhook() async {
    final saved = await _secrets.read(key: _webhookKey);
    if (saved == null) return WebhookTarget.none;
    return switch (_decode(saved)) {
      final Map<String, Object?> json => WebhookTarget.fromJson(json),
      _ => WebhookTarget.none,
    };
  }

  Future<void> saveWebhook(WebhookTarget target) => target == WebhookTarget.none
      ? _secrets.delete(key: _webhookKey)
      : _secrets.write(key: _webhookKey, value: jsonEncode(target.toJson()));

  /// [source] as JSON, or null if there's none or it doesn't parse.
  static Object? _decode(String? source) {
    if (source == null) return null;
    try {
      return jsonDecode(source);
    } on FormatException {
      return null;
    }
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
