import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/obd/elm327.dart';
import 'package:pitwall/core/session/car_reading.dart';
import 'package:pitwall/core/session/car_state.dart';

import '../obd/fake_transport.dart';

void main() {
  Future<CarReading> read(Map<String, String> replies, Set<String> keys) =>
      readCar(
        Elm327(FakeTransport(replies)),
        keys: keys,
        supportedPids: {0x0C},
      );

  test('only the battery, and the car silent: the ignition is off', () async {
    final reading = await read(
      {'ATRV': '12.4V', '0100': 'SEARCHING...\rUNABLE TO CONNECT'},
      {'battery_v'},
    );

    expect(reading, isA<CarSilent>());
  });

  test('only the battery, but the car answers: ignition on', () async {
    final reading = await read(
      {'ATRV': '12.4V', '0100': '4100BE3EB811'},
      {'battery_v'},
    );

    expect(
      reading,
      isA<CarAnswered>()
          .having((r) => r.values, 'values', {'battery_v': 12.4})
          .having((r) => r.carState, 'carState', CarState.ignitionOn),
    );
  });

  test('the engine is running when the car reports revs', () async {
    final reading = await read({'010C': '410C1AF8', 'ATRV': '12.4V'}, {'rpm'});

    expect(
      reading,
      isA<CarAnswered>()
          .having((r) => r.values, 'values', {'rpm': 1726})
          .having((r) => r.carState, 'carState', CarState.engineRunning),
    );
  });
}
