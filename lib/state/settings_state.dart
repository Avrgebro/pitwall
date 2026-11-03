import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/bluetooth/bluetooth_gateway.dart';
import '../core/platform/file_gateway.dart';
import '../core/profiles/profile_ref.dart';
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

  /// Writes to the store, one after another, so the file always ends up
  /// with the newest settings.
  Future<void> _writes = Future.value();

  /// Makes [settings] current, then writes them. Each caller awaits its own
  /// write; a failed one doesn't stop the ones after it.
  Future<void> _save(AppSettings settings) {
    state = AsyncData(settings);
    final write = _writes.then(
      (_) => ref.read(settingsStoreProvider).save(settings),
    );
    _writes = write.then((_) {}, onError: (_) {});
    return write;
  }

  /// Applies [change] to the vehicle as it is now, if it still exists.
  /// Nothing is awaited between reading it and making the change current,
  /// so an edit made meanwhile, such as a rename, isn't lost.
  Future<void> _modifyVehicle(
    String vehicleId,
    Vehicle Function(Vehicle vehicle) change,
  ) async {
    final vehicle = _current.vehicleById(vehicleId);
    if (vehicle == null) return;
    await _save(_current.withVehicle(change(vehicle)));
  }

  /// Adds a vehicle named [name] whose adapter is [adapter].
  Future<Vehicle> addVehicle({
    required String name,
    required BondedDevice adapter,
  }) async {
    final vehicle = _withAdapter(Vehicle.create(name: name.trim()), adapter);
    await _save(_current.withVehicle(vehicle));
    return vehicle;
  }

  /// Renames the vehicle. A blank name, or the one it has, changes
  /// nothing.
  Future<void> renameVehicle(String vehicleId, String name) async {
    // The last rename comes as a form goes, which can be as the app closes.
    if (!ref.mounted) return;
    final trimmed = name.trim();
    final vehicle = _current.vehicleById(vehicleId);
    if (vehicle == null || trimmed.isEmpty || trimmed == vehicle.name) return;
    await _modifyVehicle(vehicleId, (v) => v.copyWith(name: trimmed));
  }

  /// Changes the vehicle's name and adapter together, as setup does when
  /// its step is visited again.
  Future<void> updateVehicle(
    String vehicleId, {
    required String name,
    required BondedDevice adapter,
  }) async {
    await _modifyVehicle(
      vehicleId,
      (v) => _withAdapter(v.copyWith(name: name.trim()), adapter),
    );
  }

  /// Makes [adapter] the vehicle's adapter.
  Future<void> setAdapter(String vehicleId, BondedDevice adapter) =>
      _modifyVehicle(vehicleId, (v) => _withAdapter(v, adapter));

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
    await _modifyVehicle(id, (v) => v.copyWith(lastSeen: time));
  }

  Future<void> setInterval(Duration interval) =>
      _save(_current.copyWith(interval: interval));

  Future<void> setTripStart(String vehicleId, TripStart tripStart) =>
      _modifyVehicle(vehicleId, (v) => v.copyWith(tripStart: tripStart));

  /// The model year, which picks which of the profile's requests apply.
  Future<void> setModelYear(String vehicleId, int year) =>
      _modifyVehicle(vehicleId, (v) => v.copyWith(modelYear: year));

  /// Makes the head unit at [address] start the vehicle's trips.
  ///
  /// Throws [StateError] if another vehicle already uses it: a head unit
  /// belongs to one vehicle, so a connection always names one car.
  Future<void> setHeadUnit(
    String vehicleId, {
    required String address,
    required String name,
  }) async {
    final owner = _current.otherHeadUnitOwner(address, vehicleId: vehicleId);
    if (owner != null) throw StateError('${owner.name} already uses $name');
    await _modifyVehicle(
      vehicleId,
      (v) => v.copyWith(
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
    final signals = SignalSet.parse(file.contents);
    await _setProfile(
      vehicle.id,
      LoadedProfile(ProfileRef(file.name, importedAt: DateTime.now()), signals),
      modelYear: vehicle.modelYear,
    );
    return signals;
  }

  /// Makes [keys] the values the vehicle sends; see
  /// [VehicleValues.withSent].
  Future<void> setSentValues(String vehicleId, Set<String> keys) =>
      _modifyVehicle(vehicleId, (v) => v.copyWith(selectedKeys: keys));

  /// Goes back to sending the standard values.
  Future<void> resetValues(String vehicleId) =>
      _modifyVehicle(vehicleId, (v) => v.copyWith(selectedKeys: null));

  /// Puts back [profile] after it was removed, with the model year it
  /// had. Does nothing once the vehicle has another profile, so Undo can't
  /// replace a newer one.
  Future<void> restoreProfile(
    String vehicleId,
    LoadedProfile profile, {
    required int? modelYear,
  }) async {
    final vehicle = _current.vehicleById(vehicleId);
    if (vehicle == null || vehicle.profile != null) return;
    await _setProfile(vehicleId, profile, modelYear: modelYear);
  }

  /// Removes the profile, and the model year, which only picks which of
  /// its requests apply.
  Future<void> removeProfile(String vehicleId) async {
    final vehicle = _current.vehicleById(vehicleId);
    if (vehicle == null) return;
    await _setProfile(vehicleId, null, modelYear: null);
  }

  /// The one way a vehicle's profile changes: the file and the settings,
  /// in the order that never leaves the settings naming a file that isn't
  /// there. A file left behind does no harm.
  Future<void> _setProfile(
    String vehicleId,
    LoadedProfile? profile, {
    required int? modelYear,
  }) async {
    final store = ref.read(settingsStoreProvider);
    if (profile != null) {
      await store.saveProfile(vehicleId, profile.signals);
      // Deleted while the file was written: the file goes with it.
      if (_current.vehicleById(vehicleId) == null) {
        await store.deleteProfile(vehicleId);
        return;
      }
    }
    await _modifyVehicle(
      vehicleId,
      (v) => v.copyWith(profile: profile?.ref, modelYear: modelYear),
    );
    if (profile == null) await store.deleteProfile(vehicleId);
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
    appSettingsProvider.selectAsync(
      (settings) => settings.vehicleById(id)?.profile,
    ),
  );
  if (key == null) return const NoProfile();
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
  return VehicleValues.of(vehicle, switch (ref
      .watch(vehicleProfileProvider(id))
      .value) {
    LoadedProfile(:final signals) => signals,
    _ => null,
  });
});
