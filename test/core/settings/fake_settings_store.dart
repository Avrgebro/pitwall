import 'package:pitwall/core/profiles/signal_set.dart';
import 'package:pitwall/core/profiles/stored_profile.dart';
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

  /// Holds profile writes until it completes, to test what happens while
  /// one is under way.
  Future<void>? profileWrite;

  /// Holds the next settings write until it completes.
  Future<void>? nextSave;

  /// Makes every settings write fail with this.
  Object? saveError;

  /// Makes loading fail with this.
  Object? loadError;

  @override
  Future<AppSettings> load() async {
    if (loadError case final error?) throw error;
    return settings;
  }

  @override
  Future<void> save(AppSettings settings) async {
    final hold = nextSave;
    nextSave = null;
    if (hold != null) await hold;
    if (saveError case final error?) throw error;
    this.settings = settings;
  }

  @override
  Future<WebhookTarget> loadWebhook() async {
    if (webhookError case final error?) throw error;
    return webhook;
  }

  /// Makes loading the webhook fail with this.
  Object? webhookError;

  @override
  Future<void> saveWebhook(WebhookTarget target) async => webhook = target;

  /// Like the real store: a vehicle with a profile whose file is missing
  /// or broken can't load it.
  @override
  Future<StoredProfile> loadProfile(Vehicle vehicle) async {
    final ref = vehicle.profile;
    if (ref == null) return const NoProfile();
    final source = profiles[vehicle.id];
    if (source == null) return UnreadableProfile(ref);
    try {
      return LoadedProfile(ref, SignalSet.parse(source));
    } on FormatException {
      return UnreadableProfile(ref);
    }
  }

  @override
  Future<void> saveProfile(String vehicleId, SignalSet profile) async {
    if (profileWrite case final hold?) await hold;
    profiles[vehicleId] = profile.source;
  }

  @override
  Future<void> deleteProfile(String vehicleId) async =>
      profiles.remove(vehicleId);
}
