import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/vehicles/device_id.dart';
import 'package:pitwall/core/vehicles/vehicle.dart';

void main() {
  test('names become lower-case ids with dashes', () {
    expect(deviceIdFor('Hyundai Tucson'), 'hyundai-tucson');
    expect(deviceIdFor('Tucson'), 'tucson');
    expect(deviceIdFor('  Work   van  '), 'work-van');
  });

  test('accents are removed', () {
    expect(deviceIdFor('Citroën C3'), 'citroen-c3');
    expect(deviceIdFor('Camión de Papá'), 'camion-de-papa');
    expect(deviceIdFor('Straße Škoda'), 'strasse-skoda');
  });

  test('punctuation collapses into single dashes, none at the ends', () {
    expect(deviceIdFor('Mazda MX-5 (2016)!'), 'mazda-mx-5-2016');
    expect(deviceIdFor('--Tucson--'), 'tucson');
    expect(deviceIdFor('my_car.v2'), 'my-car-v2');
  });

  test('a name with nothing usable falls back to a default', () {
    expect(deviceIdFor('🚗'), fallbackDeviceId);
    expect(deviceIdFor(''), fallbackDeviceId);
  });

  test('a vehicle sends the id of its name', () {
    expect(
      const Vehicle(id: 'a1', name: 'Hyundai Tucson').deviceId,
      'hyundai-tucson',
    );
  });
}
