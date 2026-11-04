import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/obd/elm327.dart';
import 'package:pitwall/core/readings/unreported.dart';
import 'package:pitwall/core/session/car_reading.dart';
import 'package:pitwall/core/session/car_state.dart';

import '../obd/fake_transport.dart';

void main() {
  Future<CarReading> read(
    Map<String, String> replies,
    Set<String> keys, {
    Set<int> supported = const {0x0C},
  }) => readCar(
    Elm327(FakeTransport(replies)),
    keys: keys,
    profile: null,
    modelYear: null,
    supportedPids: supported,
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

  test('none of the chosen values, but the car answers: awake', () async {
    final reading = await read(
      {'0100': '4100BE3EB811', 'ATRV': '12.4V'},
      {'speed_kmh'},
    );

    expect(
      reading,
      isA<CarAwake>().having(
        (r) => r.carState,
        'carState',
        CarState.ignitionOn,
      ),
    );
  });

  test(
    'a value the car didn\'t answer for is said, while it reports others',
    () async {
      final reading = await read(
        {'ATRV': '13.9V', '010C': '410C1AF8', '010D': 'NO DATA'},
        {'battery_v', 'rpm', 'speed_kmh'},
        supported: {0x0C, 0x0D},
      );

      expect(
        reading,
        isA<CarAnswered>().having((r) => r.unreported, 'unreported', {
          'speed_kmh': Unreported.noAnswer,
        }),
      );
    },
  );

  test('just switched off, nothing answering is no news', () async {
    // The car is still awake, but no module answers any more.
    final reading = await read(
      {'ATRV': '12.1V', '010C': 'NO DATA', '0100': 'NO DATA'},
      {'battery_v', 'rpm'},
    );

    expect(
      reading,
      isA<CarAnswered>().having((r) => r.unreported, 'unreported', isEmpty),
    );
  });
}
