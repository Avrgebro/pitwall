import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/settings/settings.dart';
import 'package:pitwall/core/vehicles/vehicle.dart';

void main() {
  const tucson = Vehicle(
    id: 'a1',
    name: 'tucson',
    adapterAddress: '00:11:22:33:44:55',
    adapterName: 'OBDII',
    modelYear: 2023,
    selectedKeys: {'fuel_level_l', 'battery_v'},
    profileName: 'default.json',
    headUnitAddress: 'AA:BB:CC:DD:EE:FF',
    headUnitName: 'TUCSON BT',
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
    expect(vehicle.adapterAddress, '00:11:22:33:44:55');
    expect(vehicle.adapterName, 'OBDII');
    expect(vehicle.modelYear, 2023);
    expect(vehicle.selectedKeys, {'fuel_level_l', 'battery_v'});
    expect(vehicle.profileName, 'default.json');
    expect(vehicle.tripStart, TripStart.carBluetooth);
    expect(vehicle.headUnitAddress, 'AA:BB:CC:DD:EE:FF');
    expect(vehicle.headUnitName, 'TUCSON BT');
  });

  group('trip start', () {
    final older = Vehicle(
      id: 'b2',
      name: 'mazda',
      lastSeen: DateTime(2026, 10, 1),
    );
    final recent = Vehicle(
      id: 'a1',
      name: 'tucson',
      lastSeen: DateTime(2026, 11, 1),
    );

    test('the app-wide head unit moves to the car seen most recently', () {
      final settings = AppSettings.fromJson({
        'vehicles': [older.toJson(), recent.toJson()],
        'wakeTrigger': 'carBluetooth',
        'headUnitAddress': 'AA:BB:CC:DD:EE:FF',
        'headUnitName': 'TUCSON BT',
      });

      expect(settings.vehicleById('a1')!.headUnitName, 'TUCSON BT');
      expect(settings.vehicleById('b2')!.headUnitAddress, isNull);
      // Saved again, the app-wide fields are gone.
      expect(settings.toJson().containsKey('headUnitAddress'), isFalse);
    });

    test('a vehicle\'s own head unit wins over the app-wide one', () {
      final settings = AppSettings.fromJson({
        'vehicles': [
          older.copyWith(headUnitAddress: '11:22:33:44:55:66').toJson(),
          recent.toJson(),
        ],
        'headUnitAddress': 'AA:BB:CC:DD:EE:FF',
      });

      expect(settings.vehicleById('a1')!.headUnitAddress, isNull);
    });

    test('head units are found without regard to case', () {
      final settings = AppSettings(
        vehicles: [recent.copyWith(headUnitAddress: 'aa:bb:cc:dd:ee:ff')],
      );

      expect(settings.vehicleForHeadUnit('AA:BB:CC:DD:EE:FF')?.id, 'a1');
      expect(settings.startingHeadUnits, {'AA:BB:CC:DD:EE:FF'});
    });

    test('only vehicles started by their head unit are watched for', () {
      final settings = AppSettings(
        vehicles: [
          recent.copyWith(
            headUnitAddress: 'AA:BB:CC:DD:EE:FF',
            tripStart: TripStart.drivingDetection,
          ),
        ],
      );

      expect(settings.startingHeadUnits, isEmpty);
      expect(settings.vehicles.single.hasTripStart, isFalse);
      // It still belongs to the vehicle, so no other can take it.
      expect(settings.headUnitOwner('AA:BB:CC:DD:EE:FF')?.id, 'a1');
    });
  });

  test('the earlier single-car format becomes one vehicle', () {
    final settings = AppSettings.fromJson({
      'adapterAddress': '00:11:22:33:44:55',
      'adapterName': 'OBDII',
      'deviceName': 'tucson',
      'modelYear': 2023,
      'selectedKeys': ['fuel_level_l'],
    });

    final vehicle = settings.vehicles.single;
    expect(vehicle.name, 'tucson');
    expect(vehicle.adapterAddress, '00:11:22:33:44:55');
    expect(vehicle.selectedKeys, {'fuel_level_l'});
    expect(vehicle.id, isNotEmpty);
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

  test('copyWith can clear a value', () {
    final cleared = tucson.copyWith(modelYear: null, selectedKeys: null);

    expect(cleared.modelYear, isNull);
    expect(cleared.selectedKeys, isNull);
    expect(cleared.adapterName, 'OBDII');
  });

  group('webhook URL', () {
    test('accepts https and http URLs', () {
      expect(validateWebhookUrl('https://example.com/api/webhook/abc'), isNull);
      expect(validateWebhookUrl('http://192.168.1.10:8123/x'), isNull);
    });

    test('rejects anything else', () {
      expect(validateWebhookUrl('example.com/hook'), isNotNull);
      expect(validateWebhookUrl('ftp://example.com/hook'), isNotNull);
      expect(validateWebhookUrl(''), isNotNull);
    });
  });
}
