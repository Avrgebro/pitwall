import 'package:pitwall/core/profiles/signal_set.dart';
import 'package:pitwall/core/settings/settings.dart';
import 'package:pitwall/core/settings/settings_store.dart';
import 'package:pitwall/core/vehicles/vehicle.dart';
import 'package:pitwall/core/webhook/webhook_auth.dart';

/// Keeps settings in memory instead of on the device.
class FakeSettingsStore implements SettingsStore {
  FakeSettingsStore({this.settings = const AppSettings()});

  AppSettings settings;
  String? webhookUrl;
  WebhookAuth webhookAuth = WebhookAuth.none;
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
  Future<WebhookAuth> loadWebhookAuth() async => webhookAuth;

  @override
  Future<void> saveWebhookAuth(WebhookAuth auth) async => webhookAuth = auth;

  @override
  Future<WebhookTarget?> loadWebhookTarget() async => switch (webhookUrl) {
    final url? when url.isNotEmpty => WebhookTarget(url, webhookAuth),
    _ => null,
  };

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
