import 'package:pitwall/core/profiles/signal_set.dart';
import 'package:pitwall/core/settings/settings.dart';
import 'package:pitwall/core/settings/settings_store.dart';
import 'package:pitwall/core/vehicles/vehicle.dart';
import 'package:pitwall/core/webhook/webhook_target.dart';

/// Keeps settings in memory instead of on the device.
class FakeSettingsStore implements SettingsStore {
  FakeSettingsStore({this.settings = const AppSettings()});

  AppSettings settings;
  WebhookTarget webhook = WebhookTarget.none;
  final Map<String, String> profiles = {};

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> save(AppSettings settings) async => this.settings = settings;

  @override
  Future<WebhookTarget> loadWebhook() async => webhook;

  @override
  Future<void> saveWebhook(WebhookTarget target) async => webhook = target;

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
