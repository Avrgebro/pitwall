import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/obd/elm327.dart';
import 'package:pitwall/core/profiles/signal_set.dart';
import 'package:pitwall/core/readings/readings.dart';

import '../obd/fake_transport.dart';
import '../profiles/test_profile.dart';

void main() {
  final profile = SignalSet.parse(testProfileJson);

  group('value options', () {
    test('without a profile: battery voltage and standard values', () {
      final keys = valueOptions(null, null).map((o) => o.key);

      expect(keys, [
        'battery_v',
        'coolant_temp_c',
        'rpm',
        'speed_kmh',
        'engine_run_time_s',
        'fuel_level_pct',
        'odometer_km',
      ]);
    });

    test('profile signals are added once, unknown ones not by default', () {
      final options = valueOptions(profile, 2018);

      // odometer_km is already a standard value, so it isn't repeated.
      expect(options.where((o) => o.key == 'odometer_km'), hasLength(1));
      expect(
        options.firstWhere((o) => o.key == 'fuel_level_l').fromProfile,
        isTrue,
      );
      expect(defaultKeys(options), contains('fuel_level_l'));
      expect(defaultKeys(options), isNot(contains('test_old_only')));
    });
  });

  test('only the requests for the chosen keys are sent', () async {
    final transport = FakeTransport({
      'ATRV': '12.6V',
      '010C': '410C1AF8',
      'ATSH7A0': 'OK',
      'ATFCSH7A0': 'OK',
      'ATFCSD300000': 'OK',
      'ATFCSM1': 'OK',
      'ATCRA7A8': 'OK',
      '221234': '008\r0:621234006800\r1:32F2AAAAAAAAAA',
      'ATSH7DF': 'OK',
      'ATFCSM0': 'OK',
      'ATCRA': 'OK',
    });

    final values = await readValues(
      Elm327(transport),
      keys: {'rpm', 'fuel_level_l'},
      supportedPids: {0x0C, 0x0D, 0x2F},
      profile: profile,
      modelYear: 2023,
    );

    expect(values, {'rpm': 1726, 'fuel_level_l': 52});
    expect(transport.sent, isNot(contains('ATRV')));
    expect(transport.sent, isNot(contains('010D')));
    expect(transport.sent, contains('221234'));
  });
}
