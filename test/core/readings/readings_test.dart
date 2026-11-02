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

    test('profile signals keep their ids and are off by default', () {
      final options = valueOptions(profile, 2018);
      final profileKeys = [
        for (final option in options)
          if (option.fromProfile) option.key,
      ];

      expect(profileKeys, ['test_fuel_vol', 'test_odo_mi', 'test_old_only']);
      // A tagged odometer doesn't take over the standard one.
      expect(options.where((o) => o.key == 'odometer_km'), hasLength(1));
      expect(defaultKeys(options), isNot(contains('test_fuel_vol')));
      expect(defaultKeys(options), contains('odometer_km'));
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
      keys: {'rpm', 'test_fuel_vol'},
      supportedPids: {0x0C, 0x0D, 0x2F},
      profile: profile,
      modelYear: 2023,
    );

    expect(values, {'rpm': 1726, 'test_fuel_vol': 52});
    expect(transport.sent, isNot(contains('ATRV')));
    expect(transport.sent, isNot(contains('010D')));
    expect(transport.sent, contains('221234'));
  });
}
