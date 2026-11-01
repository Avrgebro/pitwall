import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform/file_gateway.dart';
import '../core/profiles/signal_set.dart';
import '../core/settings/settings.dart';
import '../core/vehicles/vehicle.dart';
import 'infrastructure.dart';

/// The user's settings and vehicles. Every change is saved right away.
final appSettingsProvider =
    AsyncNotifierProvider<AppSettingsNotifier, AppSettings>(
      AppSettingsNotifier.new,
    );

class AppSettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() => ref.read(settingsStoreProvider).load();

  AppSettings get _current => state.requireValue;

  Future<void> _save(AppSettings settings) async {
    state = AsyncData(settings);
    await ref.read(settingsStoreProvider).save(settings);
  }

  Future<void> saveVehicle(Vehicle vehicle) =>
      _save(_current.withVehicle(vehicle));

  /// Removes the vehicle and its profile file.
  Future<void> deleteVehicle(String id) async {
    final vehicle = _current.vehicleById(id);
    if (vehicle == null) return;
    await ref.read(settingsStoreProvider).deleteProfile(vehicle);
    await _save(_current.withoutVehicle(id));
  }

  Future<void> markSeen(String id, DateTime time) async {
    final vehicle = _current.vehicleById(id);
    if (vehicle != null) await saveVehicle(vehicle.copyWith(lastSeen: time));
  }

  Future<void> setInterval(Duration interval) =>
      _save(_current.copyWith(interval: interval));

  Future<void> setWakeTrigger(WakeTrigger trigger) =>
      _save(_current.copyWith(wakeTrigger: trigger));

  Future<void> setHeadUnit({required String address, required String name}) =>
      _save(_current.copyWith(headUnitAddress: address, headUnitName: name));

  Future<void> completeSetup() => _save(_current.copyWith(setupDone: true));

  /// Parses and saves [file] as the vehicle's profile.
  ///
  /// Throws [FormatException] if it isn't an OBDb signal set.
  Future<SignalSet> importProfile(String vehicleId, PickedFile file) async {
    final vehicle = _current.vehicleById(vehicleId);
    if (vehicle == null) throw StateError('No vehicle $vehicleId');
    final profile = SignalSet.parse(file.contents);
    final updated = await ref
        .read(settingsStoreProvider)
        .saveProfile(vehicle, file.contents, file.name);
    await saveVehicle(updated);
    return profile;
  }

  Future<void> removeProfile(String vehicleId) async {
    final vehicle = _current.vehicleById(vehicleId);
    if (vehicle == null) return;
    await saveVehicle(
      await ref.read(settingsStoreProvider).deleteProfile(vehicle),
    );
  }
}

/// One vehicle by id, or null if it doesn't exist (anymore).
final vehicleProvider = Provider.family<Vehicle?, String>(
  (ref, id) => ref.watch(appSettingsProvider).value?.vehicleById(id),
);

/// A vehicle's imported profile, parsed. Reloads only when the profile
/// itself changes, not on every settings change.
final vehicleProfileProvider = FutureProvider.family<SignalSet?, String>((
  ref,
  id,
) async {
  final key = await ref.watch(
    appSettingsProvider.selectAsync((settings) {
      final vehicle = settings.vehicleById(id);
      return (vehicle?.profileName, vehicle?.profileImportedAt);
    }),
  );
  if (key.$1 == null) return null;
  final vehicle = ref.read(appSettingsProvider).requireValue.vehicleById(id);
  return vehicle == null
      ? null
      : ref.read(settingsStoreProvider).loadProfile(vehicle);
});
