import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/bluetooth/adapter_type.dart';
import '../core/bluetooth/bluetooth_gateway.dart';
import '../core/platform/file_gateway.dart';
import '../core/profiles/profile_ref.dart';
import '../core/profiles/signal_set.dart';
import '../core/profiles/stored_profile.dart';
import '../core/readings/readings.dart';
import '../core/settings/settings.dart';
import '../core/settings/settings_store.dart';
import '../core/vehicles/vehicle.dart';
import 'infrastructure.dart';

/// The user's settings and vehicles. Every change is saved right away.
///
/// Not retried on its own when they can't be read: the app says so and
/// offers Try again, so each try is the user's, and reported once.
final appSettingsProvider =
    AsyncNotifierProvider<AppSettingsNotifier, AppSettings>(
      AppSettingsNotifier.new,
      retry: (_, _) => null,
    );

class AppSettingsNotifier extends AsyncNotifier<AppSettings> {
  /// Settings that can't be read are reported, each time they're tried,
  /// and the app shows that it couldn't; see `SettingsErrorScreen`.
  @override
  Future<AppSettings> build() async {
    try {
      return _newest = _onDisk = await ref.read(settingsStoreProvider).load();
    } on Object catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'settings',
          context: ErrorDescription('while reading the settings'),
        ),
      );
      rethrow;
    }
  }

  AppSettings get _current => state.requireValue;

  /// The newest settings: what's shown, and what the next flush writes.
  late AppSettings _newest;

  /// The settings last written, or loaded.
  late AppSettings _onDisk;

  /// Everything that writes to the store, settings and profile files,
  /// one after another.
  Future<void> _writes = Future.value();

  /// Runs [write] once the writes before it are done. Each caller awaits
  /// its own; a failed one doesn't stop the ones after it.
  Future<T> _queued<T>(Future<T> Function(SettingsStore store) write) {
    final store = ref.read(settingsStoreProvider);
    final run = _writes.then((_) => write(store));
    _writes = run.then((_) {}, onError: (_) {});
    return run;
  }

  /// Makes [settings] current, without writing them.
  void _apply(AppSettings settings) {
    state = AsyncData(settings);
    _newest = settings;
  }

  /// Makes [settings] current, then writes them.
  Future<void> _save(AppSettings settings) {
    _apply(settings);
    return _flush();
  }

  /// The flush queued and not yet started, which every change made until
  /// it starts joins.
  Future<void>? _pendingFlush;

  /// Writes the newest settings, once for however many changes came
  /// since the last write. Completes when a write that holds every change
  /// made so far is on disk, or fails with the last one that didn't make
  /// it.
  Future<void> _flush() => _pendingFlush ??= () async {
    Future<void>? answeredBy;
    await _queued(
      (store) => _writeNewest(store, handOver: (next) => answeredBy = next),
    );
    // Awaited here, outside the queue it's waiting in.
    if (answeredBy case final next?) await next;
  }();

  /// Writes the newest settings. If that fails, and nothing changed
  /// meanwhile, the settings shown go back to the ones on disk, so they
  /// never show what isn't saved, and the failure stands. A change made
  /// meanwhile has a flush of its own to come, which writes this one too:
  /// it's handed over, and its outcome is this one's.
  Future<void> _writeNewest(
    SettingsStore store, {
    required void Function(Future<void> next) handOver,
  }) async {
    // Changes from now on need another flush.
    _pendingFlush = null;
    final settings = _newest;
    try {
      await store.save(settings);
      _onDisk = settings;
    } on Object {
      if (!identical(settings, _newest)) {
        if (_pendingFlush case final next?) {
          handOver(next);
          return;
        }
      }
      if (ref.mounted) _apply(_onDisk);
      rethrow;
    }
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
    required BluetoothDevice adapter,
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
    if (trimmed.isEmpty) return;
    final vehicle = _current.vehicleById(vehicleId);
    if (vehicle == null || trimmed == vehicle.name) return;
    await _save(_current.withVehicle(vehicle.copyWith(name: trimmed)));
  }

  /// Changes the vehicle's name and adapter together, as setup does when
  /// its step is visited again.
  Future<void> updateVehicle(
    String vehicleId, {
    required String name,
    required BluetoothDevice adapter,
  }) async {
    await _modifyVehicle(
      vehicleId,
      (v) => _withAdapter(v.copyWith(name: name.trim()), adapter),
    );
  }

  /// Makes [adapter] the vehicle's adapter.
  Future<void> setAdapter(String vehicleId, BluetoothDevice adapter) =>
      _modifyVehicle(vehicleId, (v) => _withAdapter(v, adapter));

  /// The one place a device becomes a vehicle's adapter. The same adapter
  /// chosen again keeps what's known of it, and takes how it connects as
  /// Android says now; another starts afresh. A trip
  /// start the new adapter can't do goes back to the car's Bluetooth: a
  /// classic adapter doesn't wake.
  static Vehicle _withAdapter(Vehicle vehicle, BluetoothDevice device) {
    final current = vehicle.adapter;
    final adapter = current != null && current.isAt(device.address)
        ? current.chosenAgain(device)
        : VehicleAdapter.of(device);
    final wakes =
        vehicle.tripStart == TripStart.adapterWakes &&
        adapter.type == AdapterType.ble;
    return vehicle.copyWith(
      adapter: adapter,
      tripStart: wakes ? TripStart.adapterWakes : TripStart.carBluetooth,
    );
  }

  /// Removes the vehicle and its profile files; its last values follow.
  /// The settings go first, noting the vehicle as removed: a profile file
  /// left behind does no harm, but a vehicle whose file is gone would. So
  /// files that couldn't be deleted are reported, not thrown: the vehicle
  /// is gone either way, and the next start deletes them, as the settings
  /// say they're a removed vehicle's.
  Future<void> deleteVehicle(String id) async {
    final vehicle = _current.vehicleById(id);
    if (vehicle == null) return;
    await _save(_current.withoutVehicle(id));
    final deleted = await _queued(
      (store) => _reported(
        'deleting the profile files of a deleted vehicle',
        () => store.deleteProfiles(id),
      ),
    );
    if (!deleted) return;
    // Left noted, if this can't be saved: deleting again does no harm.
    await _reported(
      'noting a deleted vehicle\'s files gone',
      () => _save(_current.withFilesDeleted({id})),
    );
  }

  /// Runs [action], reporting a failure rather than throwing it, for work
  /// whose failure leaves nothing wrong: a file left behind. Says whether
  /// it was done.
  static Future<bool> _reported(
    String what,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      return true;
    } on Object catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'settings',
          context: ErrorDescription('while $what'),
        ),
      );
      return false;
    }
  }

  /// Notes that the vehicle was connected to at [time], and what its
  /// adapter can do. Called by a listener as a connection is made, which
  /// can be before the settings have loaded. Nothing awaits it, so it
  /// never throws: a failure is reported here.
  Future<void> markConnected(
    String id,
    DateTime time, {
    required bool setsFlowControl,
  }) async {
    try {
      await future;
      await _modifyVehicle(
        id,
        (v) => v.copyWith(
          lastSeen: time,
          adapter: v.adapter?.withFlowControl(setsFlowControl),
        ),
      );
    } on Object catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'settings',
          context: ErrorDescription('while noting when a vehicle was seen'),
        ),
      );
    }
  }

  Future<void> setInterval(Duration interval) =>
      _save(_current.copyWith(interval: interval));

  Future<void> setTripStart(String vehicleId, TripStart tripStart) =>
      _modifyVehicle(vehicleId, (v) => v.copyWith(tripStart: tripStart));

  /// Makes the vehicle's adapter waking start its trips, once the user
  /// lets Android watch for it, in the system dialog this shows. Returns
  /// whether they did; if not, nothing changes. Only for a Bluetooth LE
  /// adapter.
  Future<bool> startTripsWhenAdapterWakes(String vehicleId) async {
    final adapter = _current.vehicleById(vehicleId)?.adapter;
    if (adapter == null || adapter.type != AdapterType.ble) return false;
    final watched = await ref
        .read(tripServiceGatewayProvider)
        .watchAdapter(adapter.address);
    if (!watched || !ref.mounted) return false;
    await _modifyVehicle(
      vehicleId,
      (v) => v.copyWith(
        tripStart: TripStart.adapterWakes,
        // Only if it's still that adapter, as it was when asked.
        adapter: v.adapter?.address == adapter.address
            ? v.adapter?.withWatched(true)
            : v.adapter,
      ),
    );
    return true;
  }

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
        headUnit: HeadUnit(address: address, name: name),
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
      modelYear: (v) => v.modelYear,
    );
    return signals;
  }

  /// Makes [keys] the values the vehicle sends; see
  /// [VehicleValues.withSent].
  Future<void> setSentValues(String vehicleId, Set<String> keys) =>
      _modifyVehicle(vehicleId, (v) => v.withSelectedKeys(keys));

  /// Whether the vehicle's readings carry its trouble codes.
  Future<void> setTroubleCodes(String vehicleId, {required bool send}) =>
      _modifyVehicle(vehicleId, (v) => v.copyWith(sendsTroubleCodes: send));

  /// Goes back to sending the standard values.
  Future<void> resetValues(String vehicleId) =>
      _modifyVehicle(vehicleId, (v) => v.withSelectedKeys(null));

  /// Puts back [profile] after it was removed, with the model year it
  /// had. Does nothing once the vehicle has another profile, so Undo can't
  /// replace a newer one.
  Future<void> restoreProfile(
    String vehicleId,
    LoadedProfile profile, {
    required int? modelYear,
  }) async {
    await _setProfile(
      vehicleId,
      profile,
      modelYear: (_) => modelYear,
      when: (v) => v.profile == null,
    );
  }

  /// Removes the profile, and the model year, which only picks which of
  /// its requests apply.
  Future<void> removeProfile(String vehicleId) async {
    await _setProfile(vehicleId, null, modelYear: (_) => null);
  }

  /// The one way a vehicle's profile changes. Each profile has a file of
  /// its own, so the settings always name exactly the file they mean:
  ///
  /// 1. In the write queue, deciding from the vehicle as it is then, the
  ///    new file is written and the change made current. Nothing happens
  ///    unless the vehicle exists and [when] holds for it.
  /// 2. The settings are written.
  /// 3. Whichever of the old and new files the settings no longer name is
  ///    deleted: the old one once the change is saved, or the new one if
  ///    it couldn't be and the settings went back.
  Future<void> _setProfile(
    String vehicleId,
    LoadedProfile? profile, {
    required int? Function(Vehicle vehicle) modelYear,
    bool Function(Vehicle vehicle)? when,
  }) async {
    final (:changed, :old) = await _queued((store) async {
      const unchanged = (changed: false, old: null);
      final vehicle = _newest.vehicleById(vehicleId);
      if (vehicle == null || !(when?.call(vehicle) ?? true)) return unchanged;
      if (profile != null) {
        await store.saveProfile(vehicleId, profile.ref, profile.signals);
      }
      // Deleted while the file was written: its own delete, queued after
      // this, takes the file.
      final current = _newest.vehicleById(vehicleId);
      if (current == null) return unchanged;
      _apply(
        _newest.withVehicle(
          current.withProfile(profile?.ref, modelYear: modelYear(current)),
        ),
      );
      return (changed: true, old: current.profile);
    });
    if (!changed) return;
    try {
      await _flush();
    } finally {
      await _deleteUnnamed(vehicleId, [?old, ?profile?.ref]);
    }
  }

  /// Deletes the files of [refs] that the vehicle's settings, as written,
  /// don't name. Never throws: a file left behind does no harm, so the
  /// change's own outcome stands, and the next start sweeps it.
  Future<void> _deleteUnnamed(String vehicleId, List<ProfileRef> refs) =>
      _queued(
        (store) =>
            _reported('deleting a profile file no longer named', () async {
              String? named(AppSettings settings) =>
                  switch (settings.vehicleById(vehicleId)?.profile) {
                    final ref? => ProfileFiles.fileName(vehicleId, ref),
                    null => null,
                  };
              final kept = {named(_onDisk), named(_newest)};
              for (final ref in refs) {
                if (!kept.contains(ProfileFiles.fileName(vehicleId, ref))) {
                  await store.deleteProfile(vehicleId, ref);
                }
              }
            }),
      );
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
  return VehicleValues.of(vehicle, switch (ref.watch(
    vehicleProfileProvider(id),
  )) {
    // Kept while it reloads, as after an import.
    AsyncValue(:final value?) => value,
    // Loading a profile maps every failure to UnreadableProfile, so an
    // error can only come from the settings; it reads the same way.
    AsyncError() => switch (vehicle.profile) {
      final ref? => UnreadableProfile(ref),
      null => const NoProfile(),
    },
    AsyncLoading() => null,
  });
});
