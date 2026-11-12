import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/bluetooth/adapter_type.dart';
import 'package:pitwall/core/profiles/profile_ref.dart';
import 'package:pitwall/core/settings/settings.dart';
import 'package:pitwall/core/trips/trip_target.dart';
import 'package:pitwall/core/vehicles/vehicle.dart';

void main() {
  const tucson = Vehicle(
    id: 'a1',
    name: 'tucson',
    adapter: VehicleAdapter(
      address: '00:11:22:33:44:55',
      name: 'OBDII',
      type: AdapterType.classic,
    ),

    modelYear: 2023,
    selectedKeys: {'tucson_fli_vol', 'battery_v'},
    profile: ProfileRef('default.json'),
    headUnit: HeadUnit(address: 'AA:BB:CC:DD:EE:FF', name: 'TUCSON BT'),
  );

  test('settings survive a round trip through JSON', () {
    const settings = AppSettings(
      vehicles: [tucson],
      interval: Duration(seconds: 30),
    );

    final restored = AppSettings.fromJson(settings.toJson());

    expect(restored.interval, const Duration(seconds: 30));
    final vehicle = restored.vehicles.single;
    expect(vehicle.id, 'a1');
    expect(vehicle.name, 'tucson');
    expect(vehicle.adapter?.address, '00:11:22:33:44:55');
    expect(vehicle.adapter?.name, 'OBDII');
    expect(vehicle.modelYear, 2023);
    expect(vehicle.selectedKeys, {'tucson_fli_vol', 'battery_v'});
    expect(vehicle.profile, const ProfileRef('default.json'));
    expect(vehicle.tripStart, TripStart.carBluetooth);
    expect(vehicle.headUnit?.address, 'AA:BB:CC:DD:EE:FF');
    expect(vehicle.headUnit?.name, 'TUCSON BT');
  });

  group('trip start', () {
    final recent = Vehicle(
      id: 'a1',
      name: 'tucson',
      lastSeen: DateTime(2026, 11, 1),
    );

    test('head units are found without regard to case', () {
      final settings = AppSettings(
        vehicles: [
          recent.copyWith(
            headUnit: HeadUnit(
              address: 'aa:bb:cc:dd:ee:ff',
              name: 'aa:bb:cc:dd:ee:ff',
            ),
          ),
        ],
      );

      expect(settings.vehicleForHeadUnit('AA:BB:CC:DD:EE:FF')?.id, 'a1');
      expect(settings.startingHeadUnits, {'AA:BB:CC:DD:EE:FF'});
    });

    test('only vehicles started by their head unit are watched for', () {
      final settings = AppSettings(
        vehicles: [
          recent.copyWith(
            headUnit: HeadUnit(
              address: 'AA:BB:CC:DD:EE:FF',
              name: 'AA:BB:CC:DD:EE:FF',
            ),
            tripStart: TripStart.adapterWakes,
          ),
        ],
      );

      expect(settings.startingHeadUnits, isEmpty);
      // It still belongs to the vehicle, so no other can take it.
      expect(settings.headUnitOwner('AA:BB:CC:DD:EE:FF')?.id, 'a1');
    });
  });

  test('only adapters that wake and are watched start trips', () {
    VehicleAdapter adapter({required bool watched}) => VehicleAdapter(
      address: 'C0:FF:EE:00:00:01',
      name: 'IOS-Vlink',
      type: AdapterType.ble,
      watched: watched,
    );
    final watched = AppSettings(
      vehicles: [
        Vehicle(
          id: 'a1',
          name: 'Tucson',
          adapter: adapter(watched: true),
          tripStart: TripStart.adapterWakes,
        ),
      ],
    );

    expect(watched.startingAdapters, {'C0:FF:EE:00:00:01'});
    expect(
      watched
          .tripCandidates(const AdapterTarget('c0:ff:ee:00:00:01'))
          .single
          .id,
      'a1',
    );

    final unwatched = AppSettings(
      vehicles: [
        Vehicle(
          id: 'a1',
          name: 'Tucson',
          adapter: adapter(watched: false),
          tripStart: TripStart.adapterWakes,
        ),
      ],
    );
    expect(unwatched.startingAdapters, isEmpty);
    expect(
      unwatched.tripCandidates(const AdapterTarget('C0:FF:EE:00:00:01')),
      isEmpty,
    );
  });

  test('a head unit another vehicle has is that vehicle\'s', () {
    const settings = AppSettings(
      vehicles: [
        Vehicle(
          id: 'tucson',
          headUnit: HeadUnit(
            address: 'AA:BB:CC:DD:EE:FF',
            name: 'AA:BB:CC:DD:EE:FF',
          ),
        ),
        Vehicle(id: 'mazda'),
      ],
    );

    expect(
      settings.otherHeadUnitOwner('aa:bb:cc:dd:ee:ff', vehicleId: 'mazda')?.id,
      'tucson',
    );
    // Its own head unit isn't another's.
    expect(
      settings.otherHeadUnitOwner('AA:BB:CC:DD:EE:FF', vehicleId: 'tucson'),
      isNull,
    );
  });

  group('trip candidates', () {
    final tucson = Vehicle(
      id: 'tucson',
      adapter: VehicleAdapter(
        address: 'T1',
        name: 'T1',
        type: AdapterType.classic,
      ),
      headUnit: HeadUnit(
        address: 'AA:BB:CC:DD:EE:FF',
        name: 'AA:BB:CC:DD:EE:FF',
      ),
      lastSeen: DateTime(2026, 10, 30),
    );
    final mazda = Vehicle(
      id: 'mazda',
      adapter: VehicleAdapter(
        address: 'M1',
        name: 'M1',
        type: AdapterType.classic,
      ),
      lastSeen: DateTime(2026, 11, 1),
    );
    const neverSeen = Vehicle(
      id: 'kia',
      adapter: VehicleAdapter(
        address: 'K1',
        name: 'K1',
        type: AdapterType.classic,
      ),
    );
    const noAdapter = Vehicle(id: 'bike');
    final settings = AppSettings(
      vehicles: [neverSeen, tucson, noAdapter, mazda],
    );

    test('a head unit names its own vehicle only', () {
      expect(
        settings
            .tripCandidates(const HeadUnitTarget('aa:bb:cc:dd:ee:ff'))
            .map((v) => v.id),
        ['tucson'],
      );
      expect(settings.tripCandidates(const HeadUnitTarget('99')), isEmpty);
    });

    test('the app can name one vehicle', () {
      expect(
        settings.tripCandidates(const VehicleTarget('mazda')).map((v) => v.id),
        ['mazda'],
      );
      // Without an adapter there is nothing to connect to.
      expect(settings.tripCandidates(const VehicleTarget('bike')), isEmpty);
    });

    test('any vehicle tries the most recently seen first', () {
      expect(
        settings.tripCandidates(const AnyVehicleTarget()).map((v) => v.id),
        ['mazda', 'tucson', 'kia'],
      );
    });
  });

  test('missing or broken fields fall back to defaults', () {
    final settings = AppSettings.fromJson({
      'vehicles': [
        {'name': '', 'modelYear': 'soon', 'selectedKeys': 'all'},
        'not a vehicle',
      ],
      'intervalSeconds': 1,
    });

    expect(settings.interval, AppSettings.defaultInterval);
    final vehicle = settings.vehicles.single;
    expect(vehicle.name, Vehicle.defaultName);
    expect(vehicle.modelYear, isNull);
    expect(vehicle.selectedKeys, isNull);
  });

  test('vehicles are found by adapter, added and replaced by id', () {
    var settings = const AppSettings(vehicles: [tucson]);

    expect(settings.vehicleForAdapter('00:11:22:33:44:55')?.id, 'a1');
    expect(settings.vehicleForAdapter('AA:BB:CC:DD:EE:FF'), isNull);

    settings = settings.withVehicle(tucson.copyWith(name: 'family car'));
    expect(settings.vehicles.single.name, 'family car');

    settings = settings.withVehicle(Vehicle.create(name: 'second'));
    expect(settings.vehicles.map((v) => v.name), ['family car', 'second']);

    settings = settings.withoutVehicle('a1');
    expect(settings.vehicles.map((v) => v.name), ['second']);
  });

  test('the profile and the chosen values can be cleared', () {
    final cleared = tucson
        .withProfile(null, modelYear: null)
        .withSelectedKeys(null);

    expect(cleared.modelYear, isNull);
    expect(cleared.selectedKeys, isNull);
    expect(cleared.adapter?.name, 'OBDII');
  });
}
