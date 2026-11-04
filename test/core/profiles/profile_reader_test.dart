import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/obd/elm327.dart';
import 'package:pitwall/core/profiles/profile_reader.dart';
import 'package:pitwall/core/profiles/signal_set.dart';
import 'package:pitwall/core/readings/unreported.dart';

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
    '220100': '62010007',
    'ATSH7DF': 'OK',
    'ATFCSM0': 'OK',
    'ATCRA': 'OK',
  };

  test(
    'reads the signals for the model year and restores the broadcast',
    () async {
      final transport = FakeTransport(replies);

      final (:values, unreported: _, unanswered: _, answered: _) =
          await readProfile(Elm327(transport), signalSet, 2023);

      // Raw ids and the profile's own units: miles stay miles.
      expect(values['test_fuel_vol'], 52);
      expect(values['test_odo_mi'], 13042);
      expect(values, isNot(contains('test_old_only')));
      // The fcm1 request, with the same flow control as any module.
      expect(values['test_fcm1'], 7);
      expect(transport.sent, [
        'ATSH7A0',
        'ATFCSH7A0',
        'ATFCSD300000',
        'ATFCSM1',
        'ATCRA7A8',
        '221234',
        'ATSH7E0',
        'ATFCSH7E0',
        'ATCRA7E8',
        '220100',
        'ATSH7DF',
        'ATFCSM0',
        'ATCRA',
      ]);
    },
  );

  test('without flow control, requests that need it aren\'t sent', () async {
    final transport = FakeTransport({
      ...replies,
      'ATZ': 'ELM327 v2.1',
      'ATE0': 'OK',
      'ATL0': 'OK',
      'ATS0': 'OK',
      'ATH0': 'OK',
      'ATSP0': 'OK',
      'ATFCSH7E0': '?',
    });
    final elm = Elm327(transport);
    await elm.initialize();
    transport.sent.clear();

    final (:values, :unreported, unanswered: _, answered: _) =
        await readProfile(elm, signalSet, 2023);

    expect(values, isNot(contains('test_fcm1')));
    expect(unreported['test_fcm1'], Unreported.adapterCannot);
    // Not even addressed: known before reading, not found out while.
    expect(transport.sent, isNot(contains('220100')));
    expect(transport.sent, isNot(contains('ATSH7E0')));
    expect(transport.sent, isNot(contains('ATFCSH7A0')));
    // The rest is still read; the long reply from 7A0 just comes back short.
    expect(transport.sent, contains('221234'));
  });

  test('older model years include their extra commands', () async {
    final transport = FakeTransport(replies);

    final (:values, unreported: _, unanswered: _, answered: _) =
        await readProfile(Elm327(transport), signalSet, 2018);

    expect(values['test_old_only'], 0x2A);
    expect(transport.sent, containsAllInOrder(['ATSH7E0', '220042']));
  });

  test('a refused request gives no values', () async {
    final transport = FakeTransport({...replies, '221234': '7F2231'});

    final (:values, :unreported, unanswered: _, answered: _) =
        await readProfile(Elm327(transport), signalSet, 2023);

    expect(values, isNot(contains('test_fuel_vol')));
    expect(values, isNot(contains('test_odo_mi')));
    // Whether that says something depends on the module; see readCar.
    expect(unreported, isNot(contains('test_fuel_vol')));
  });

  test('a value its reply is too short for is said to be missing', () async {
    // The odometer's bytes are cut off; the fuel's are there.
    final transport = FakeTransport({...replies, '221234': '6212340068'});

    final (:values, :unreported, unanswered: _, answered: _) =
        await readProfile(Elm327(transport), signalSet, 2023);

    expect(values['test_fuel_vol'], 52);
    expect(unreported, {'test_odo_mi': Unreported.notInReply});
  });

  test('a value the car marks unavailable says so', () async {
    final profile = SignalSet.parse(r'''
      {"commands": [{"hdr": "7E0", "rax": "7E8", "cmd": {"22": "0001"},
        "signals": [{"id": "SOC", "fmt": {"len": 8, "nullmax": 255}}]}]}
    ''');
    final transport = FakeTransport({...replies, '220001': '620001FF'});

    final (:values, :unreported, unanswered: _, answered: _) =
        await readProfile(Elm327(transport), profile, 2023);

    expect(values, isEmpty);
    expect(unreported, {'soc': Unreported.unavailable});
  });

  test('a key two requests carry is read through the first only', () async {
    final profile = SignalSet.parse(r'''
      {"commands": [
        {"hdr": "7E0", "rax": "7E8", "cmd": {"22": "0001"},
         "signals": [{"id": "SHARED", "fmt": {"len": 8}}]},
        {"hdr": "7E0", "rax": "7E8", "cmd": {"22": "0002"},
         "signals": [{"id": "SHARED", "fmt": {"len": 8}},
                     {"id": "OWN", "fmt": {"bix": 8, "len": 8}}]}
      ]}
    ''');
    final transport = FakeTransport({
      ...replies,
      // The first request's reply holds no data for it.
      '220001': '620001',
      '220002': '6200020907',
    });

    final (:values, unreported: _, unanswered: _, answered: _) =
        await readProfile(Elm327(transport), profile, 2023);

    // Only ever from the first request, whose name and unit the profile's
    // summary shows: the second request's value, in its own terms, isn't
    // taken instead.
    expect(values, isNot(contains('shared')));
    expect(values['own'], 7);
  });
}
