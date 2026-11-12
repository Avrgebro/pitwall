import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/bluetooth/adapter_type.dart';
import 'package:pitwall/core/bluetooth/bluetooth_gateway.dart';
import 'package:pitwall/core/profiles/profile_ref.dart';
import 'package:pitwall/core/vehicles/vehicle.dart';

void main() {
  const ready = Vehicle(
    id: 'tucson',
    adapter: VehicleAdapter(
      address: '00:1D:A5:68:98:8B',
      name: '00:1D:A5:68:98:8B',
      type: AdapterType.classic,
    ),
    headUnit: HeadUnit(address: 'AA:BB:CC:DD:EE:FF', name: 'AA:BB:CC:DD:EE:FF'),
  );

  test('a vehicle with an adapter and a head unit needs nothing', () {
    expect(ready.needs, isEmpty);
  });

  test('a missing adapter comes before a missing head unit', () {
    const bare = Vehicle(id: 'tucson');
    expect(bare.needs, [VehicleNeed.adapter, VehicleNeed.headUnit]);
  });

  test('waking needs a Bluetooth LE adapter that Android watches for', () {
    final classic = ready.copyWith(tripStart: TripStart.adapterWakes);
    expect(classic.needs, [VehicleNeed.bluetoothLeAdapter]);
    expect(classic.startingAdapter, isNull);

    const bluetoothLe = VehicleAdapter(
      address: 'C0:FF:EE:00:00:01',
      name: 'IOS-Vlink',
      type: AdapterType.ble,
    );
    final unwatched = classic.copyWith(adapter: bluetoothLe);
    expect(unwatched.needs, [VehicleNeed.adapterWatch]);

    final watched = classic.copyWith(adapter: bluetoothLe.withWatched(true));
    expect(watched.needs, isEmpty);
    expect(watched.startingAdapter, 'C0:FF:EE:00:00:01');
    // Its head unit no longer starts trips.
    expect(watched.startingHeadUnit, isNull);
  });

  test('another adapter isn\'t watched until confirmed', () {
    const device = BluetoothDevice(
      name: 'IOS-Vlink',
      address: 'C0:FF:EE:00:00:02',
      type: AdapterType.ble,
    );
    expect(VehicleAdapter.of(device).watched, isFalse);
  });

  test('every way of copying keeps the fields it doesn\'t change', () {
    // Every field set, so a copy that drops one shows.
    final full = Vehicle(
      id: 'tucson',
      name: 'Tucson',
      adapter: ready.adapter?.withFlowControl(false),
      tripStart: TripStart.adapterWakes,
      headUnit: ready.headUnit,
      modelYear: 2023,
      selectedKeys: const {'rpm', 'battery_v'},
      profile: ProfileRef('default.json', importedAt: DateTime.utc(2026, 11)),
      lastSeen: DateTime.utc(2026, 11, 3),
      // Off, so a copy that falls back to the default shows.
      sendsTroubleCodes: false,
    );
    expect(full.toJson().values, everyElement(isNotNull));

    for (final copy in [
      full.copyWith(),
      Vehicle.fromJson(full.toJson()),
      full.withProfile(full.profile, modelYear: full.modelYear),
      full.withSelectedKeys(full.selectedKeys),
    ]) {
      expect(copy.toJson(), full.toJson());
    }
  });

  test('a paired device becomes the adapter as it is', () {
    const device = BluetoothDevice(
      name: 'vLinker MC+',
      address: '00:1D:A5:68:98:8B',
      type: AdapterType.ble,
    );

    expect(
      VehicleAdapter.of(device),
      const VehicleAdapter(
        address: '00:1D:A5:68:98:8B',
        name: 'vLinker MC+',
        type: AdapterType.ble,
      ),
    );
  });
}
