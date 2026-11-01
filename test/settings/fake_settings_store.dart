import 'package:pitwall/profiles/signal_set.dart';
import 'package:pitwall/settings/settings.dart';
import 'package:pitwall/settings/settings_store.dart';
import 'package:pitwall/vehicles/vehicle.dart';

/// Keeps settings in memory instead of on the device.
class FakeSettingsStore implements SettingsStore {
  FakeSettingsStore({this.settings = const AppSettings()});

  AppSettings settings;
  String? webhookUrl;
  final Map<String, String> profiles = {};

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> save(AppSettings settings) async => this.settings = settings;

  @override
  Future<String?> loadWebhookUrl() async => webhookUrl;

  @override
  Future<void> saveWebhookUrl(String? url) async => webhookUrl = url;

  @override
  Future<SignalSet?> loadProfile(Vehicle vehicle) async =>
      switch (profiles[vehicle.id]) {
        final source? => SignalSet.parse(source),
        null => null,
      };

  @override
  Future<Vehicle> saveProfile(
    Vehicle vehicle,
    String source,
    String name,
  ) async {
    profiles[vehicle.id] = source;
    return vehicle.copyWith(profileName: name);
  }

  @override
  Future<Vehicle> deleteProfile(Vehicle vehicle) async {
    profiles.remove(vehicle.id);
    return vehicle.copyWith(profileName: null);
  }
}
