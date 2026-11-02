import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/bluetooth/bluetooth_gateway.dart';
import '../core/platform/file_gateway.dart';
import '../core/profiles/signal_set.dart';
import '../core/profiles/stored_profile.dart';
import '../core/readings/readings.dart';
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

  /// Adds a vehicle named [name] whose adapter is [adapter].
  Future<Vehicle> addVehicle({
    required String name,
    required BondedDevice adapter,
  }) async {
    final vehicle = _withAdapter(Vehicle.create(name: name.trim()), adapter);
    await saveVehicle(vehicle);
    return vehicle;
  }

  /// Renames the vehicle. A blank name, or the one it has, changes
  /// nothing.
  Future<void> renameVehicle(String vehicleId, String name) async {
    // The last rename comes as a form goes, which can be as the app closes.
    if (!ref.mounted) return;
    final vehicle = _current.vehicleById(vehicleId);
    final trimmed = name.trim();
    if (vehicle == null || trimmed.isEmpty || trimmed == vehicle.name) return;
    await saveVehicle(vehicle.copyWith(name: trimmed));
  }

  /// Makes [adapter] the vehicle's adapter.
  Future<void> setAdapter(String vehicleId, BondedDevice adapter) async {
    final vehicle = _current.vehicleById(vehicleId);
    if (vehicle != null) await saveVehicle(_withAdapter(vehicle, adapter));
  }

  /// The one place a device becomes a vehicle's adapter.
  static Vehicle _withAdapter(Vehicle vehicle, BondedDevice adapter) =>
      vehicle.copyWith(
        adapterAddress: adapter.address,
        adapterName: adapter.name,
        adapterType: adapter.type,
      );

  /// Removes the vehicle and its profile file; its last values follow.
  /// The settings go first: a profile file left behind does no harm, but
  /// a vehicle whose file is gone would.
  Future<void> deleteVehicle(String id) async {
    final vehicle = _current.vehicleById(id);
    if (vehicle == null) return;
    await _save(_current.withoutVehicle(id));
    await ref.read(settingsStoreProvider).deleteProfile(id);
  }

  /// Called by a listener as a connection is made, which can be before
  /// the settings have loaded.
  Future<void> markSeen(String id, DateTime time) async {
    await future;
    final vehicle = _current.vehicleById(id);
    if (vehicle != null) await saveVehicle(vehicle.copyWith(lastSeen: time));
  }

  Future<void> setInterval(Duration interval) =>
      _save(_current.copyWith(interval: interval));

  Future<void> setTripStart(String vehicleId, TripStart tripStart) async {
    final vehicle = _current.vehicleById(vehicleId);
    if (vehicle != null) {
      await saveVehicle(vehicle.copyWith(tripStart: tripStart));
    }
  }

  /// Makes the head unit at [address] start the vehicle's trips.
  ///
  /// Throws [StateError] if another vehicle already uses it: a head unit
  /// belongs to one vehicle, so a connection always names one car.
  Future<void> setHeadUnit(
    String vehicleId, {
    required String address,
    required String name,
  }) async {
    final vehicle = _current.vehicleById(vehicleId);
    if (vehicle == null) return;
    final owner = _current.otherHeadUnitOwner(address, vehicleId: vehicleId);
    if (owner != null) throw StateError('${owner.name} already uses $name');
    await saveVehicle(
      vehicle.copyWith(
        tripStart: TripStart.carBluetooth,
        headUnitAddress: address,
        headUnitName: name,
      ),
    );
  }

  Future<void> completeSetup() => _save(_current.copyWith(setupDone: true));

  /// Parses and saves [file] as the vehicle's profile.
  ///
  /// Throws [FormatException] if it isn't an OBDb signal set.
  Future<SignalSet> importProfile(String vehicleId, PickedFile file) async {
    final vehicle = _current.vehicleById(vehicleId);
    if (vehicle == null) throw StateError('No vehicle $vehicleId');
    final profile = SignalSet.parse(file.contents);
    await ref.read(settingsStoreProvider).saveProfile(vehicleId, profile);
    await saveVehicle(
      vehicle.copyWith(
        profileName: file.name,
        profileImportedAt: DateTime.now(),
      ),
    );
    return profile;
  }

  /// Makes [keys] the values the vehicle sends; see
  /// [VehicleValues.withSent].
  Future<void> setSentValues(String vehicleId, Set<String> keys) async {
    final vehicle = _current.vehicleById(vehicleId);
    if (vehicle == null) return;
    await saveVehicle(vehicle.copyWith(selectedKeys: keys));
  }

  /// Goes back to sending the standard values.
  Future<void> resetValues(String vehicleId) async {
    final vehicle = _current.vehicleById(vehicleId);
    if (vehicle == null) return;
    await saveVehicle(vehicle.copyWith(selectedKeys: null));
  }

  /// Puts back the profile [before] had, after it was removed: the file,
  /// its name, when it was imported, and the model year. Does nothing once
  /// the vehicle has another profile, so Undo can't replace a newer one.
  Future<void> restoreProfile(Vehicle before, SignalSet profile) async {
    final vehicle = _current.vehicleById(before.id);
    if (vehicle == null || vehicle.profileName != null) return;
    await ref.read(settingsStoreProvider).saveProfile(before.id, profile);
    await saveVehicle(
      vehicle.copyWith(
        profileName: before.profileName,
        profileImportedAt: before.profileImportedAt,
        modelYear: before.modelYear,
      ),
    );
  }

  Future<void> removeProfile(String vehicleId) async {
    final vehicle = _current.vehicleById(vehicleId);
    if (vehicle == null) return;
    await ref.read(settingsStoreProvider).deleteProfile(vehicleId);
    // The model year only picks which of the profile's requests apply.
    await saveVehicle(
      vehicle.copyWith(
        profileName: null,
        profileImportedAt: null,
        modelYear: null,
      ),
    );
  }
}

/// One vehicle by id, or null if it doesn't exist (anymore).
final vehicleProvider = Provider.family<Vehicle?, String>(
  (ref, id) => ref.watch(appSettingsProvider).value?.vehicleById(id),
);

/// A vehicle's profile as found on the phone. Reloads only when the
/// profile itself changes, not on every settings change.
final vehicleProfileProvider = FutureProvider.family<StoredProfile, String>((
  ref,
  id,
) async {
  final key = await ref.watch(
    appSettingsProvider.selectAsync((settings) {
      final vehicle = settings.vehicleById(id);
      return (vehicle?.profileName, vehicle?.profileImportedAt);
    }),
  );
  if (key.$1 == null) return const NoProfile();
  final vehicle = ref.read(appSettingsProvider).requireValue.vehicleById(id);
  return vehicle == null
      ? const NoProfile()
      : ref.read(settingsStoreProvider).loadProfile(vehicle);
});

/// A vehicle's values: what it can send, and what it does. Null while
/// the vehicle doesn't exist; profile values join once the profile loads.
final vehicleValuesProvider = Provider.family<VehicleValues?, String>((
  ref,
  id,
) {
  final vehicle = ref.watch(vehicleProvider(id));
  if (vehicle == null) return null;
  return VehicleValues.of(
    vehicle,
    ref.watch(vehicleProfileProvider(id)).value?.signals,
  );
});
