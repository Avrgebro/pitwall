import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/obd/elm327.dart';
import 'package:pitwall/profiles/profile_reader.dart';
import 'package:pitwall/profiles/signal_set.dart';

import '../obd/fake_transport.dart';
import 'test_profile.dart';

void main() {
  final signalSet = SignalSet.parse(testProfileJson);

  const replies = {
    'ATSH7A0': 'OK',
    'ATFCSH7A0': 'OK',
    'ATFCSD300000': 'OK',
    'ATFCSM1': 'OK',
    'ATCRA7A8': 'OK',
    // Multi-frame: 8 bytes, 62 12 34 then the data.
    '221234': '008\r0:621234006800\r1:32F2AAAAAAAAAA',
    'ATSH7E0': 'OK',
    'ATFCSH7E0': 'OK',
    'ATCRA7E8': 'OK',
    '220042': '6200422A',
    'ATSH7DF': 'OK',
    'ATFCSM0': 'OK',
    'ATCRA': 'OK',
  };

  test(
    'reads the signals for the model year and restores the broadcast',
    () async {
      final transport = FakeTransport(replies);

      final values = await readProfile(Elm327(transport), signalSet, 2023);

      expect(values['fuel_level_l'], 52);
      expect(values['odometer_km'], closeTo(20989.06, 0.01));
      expect(values, isNot(contains('test_old_only')));
      expect(transport.sent, [
        'ATSH7A0',
        'ATFCSH7A0',
        'ATFCSD300000',
        'ATFCSM1',
        'ATCRA7A8',
        '221234',
        'ATSH7DF',
        'ATFCSM0',
        'ATCRA',
      ]);
    },
  );

  test('older model years include their extra commands', () async {
    final transport = FakeTransport(replies);

    final values = await readProfile(Elm327(transport), signalSet, 2018);

    expect(values['test_old_only'], 0x2A);
    expect(transport.sent, containsAllInOrder(['ATSH7E0', '220042']));
  });

  test('a refused request gives no values', () async {
    final transport = FakeTransport({...replies, '221234': '7F2231'});

    final values = await readProfile(Elm327(transport), signalSet, 2023);

    expect(values, isEmpty);
  });

  test('profile fuel in litres replaces the standard percent', () {
    final merged = mergeValues(
      {'fuel_level_pct': 0, 'rpm': 800},
      {'fuel_level_l': 52},
    );

    expect(merged, {'rpm': 800, 'fuel_level_l': 52});
  });
}
