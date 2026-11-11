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

  test('a trip start that is not built yet is a need', () {
    final detecting = ready.copyWith(tripStart: TripStart.drivingDetection);
    expect(detecting.needs, [VehicleNeed.supportedTripStart]);
  });

  test('every way of copying keeps the fields it doesn\'t change', () {
    // Every field set, so a copy that drops one shows.
    final full = Vehicle(
      id: 'tucson',
      name: 'Tucson',
      adapter: ready.adapter?.withFlowControl(false),
      tripStart: TripStart.drivingDetection,
      headUnit: ready.headUnit,
      modelYear: 2023,
      selectedKeys: const {'rpm', 'battery_v'},
      profile: ProfileRef('default.json', importedAt: DateTime.utc(2026, 11)),
      lastSeen: DateTime.utc(2026, 11, 3),
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
