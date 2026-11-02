import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/vehicles/vehicle.dart';

void main() {
  const ready = Vehicle(
    id: 'tucson',
    adapterAddress: '00:1D:A5:68:98:8B',
    headUnitAddress: 'AA:BB:CC:DD:EE:FF',
  );

  test('a vehicle with an adapter and a head unit needs nothing', () {
    expect(ready.needs, isEmpty);
  });

  test('a missing adapter comes before a missing head unit', () {
    const bare = Vehicle(id: 'tucson');
    expect(bare.needs, [VehicleNeed.adapter, VehicleNeed.headUnit]);
  });

  test('a head unit name alone is not a trip start', () {
    final named = ready.copyWith(headUnitAddress: null, headUnitName: 'T');
    expect(named.needs, [VehicleNeed.headUnit]);
  });

  test('a trip start that is not built yet is a need', () {
    final detecting = ready.copyWith(tripStart: TripStart.drivingDetection);
    expect(detecting.needs, [VehicleNeed.supportedTripStart]);
  });
}
