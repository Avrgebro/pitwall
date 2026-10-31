import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/obd/elm327.dart';
import 'package:pitwall/obd/pids.dart';

import 'fake_transport.dart';

/// Replies recorded from a real car (two ECUs answering) through an
/// "ELM327 v2.1" classic Bluetooth adapter, engine idling.
const recordedReplies = {
  'ATZ': 'ATZ\rELM327 v2.1\r\n',
  'ATE0': 'ATE0\rOK\r\n',
  'ATL0': 'OK',
  'ATS0': 'OK',
  'ATH0': 'OK',
  'ATSP0': 'OK',
  '0100': 'SEARCHING...\r4100BE3EA813\r410098188013',
  '0120': '41208007F001\r412080018001',
  '0140': '4140FED28405\r4140C0800000',
  '0160': '416062000001',
  '0180': '418000040009',
  '01A0': '41A004000000',
  'ATRV': '13.6V',
  '0105': '410561\r410561',
  '010C': '410C0C84\r410C0CA6',
  '010D': '410D00\r410D00',
  '012F': '412F00',
  '01A6': '41A60005301D',
};

void main() {
  late Elm327 elm;

  setUp(() async {
    elm = Elm327(FakeTransport(recordedReplies));
    expect(await elm.initialize(), 'ELM327 v2.1');
  });

  test('supported PIDs combine both ECUs across all ranges', () async {
    final supported = await elm.supportedPids();

    expect(supported.toList()..sort(), [
      0x01, 0x03, 0x04, 0x05, 0x06, 0x07, 0x0B, 0x0C, 0x0D, 0x0E, //
      0x0F, 0x11, 0x13, 0x15, 0x1C, 0x1F, 0x20, 0x21, 0x2E, 0x2F,
      0x30, 0x31, 0x32, 0x33, 0x34, 0x40, 0x41, 0x42, 0x43, 0x44,
      0x45, 0x46, 0x47, 0x49, 0x4A, 0x4C, 0x4F, 0x51, 0x56, 0x5E,
      0x60, 0x62, 0x63, 0x67, 0x80, 0x8E, 0x9D, 0xA0, 0xA6,
    ]);
  });

  test('reads decode to the values shown on screen', () async {
    Future<double?> read(int pid) => elm.read(standardPidsById[pid]!);

    expect(await elm.readBatteryVoltage(), 13.6);
    expect(await read(0x05), 57);
    // The two ECUs disagree slightly; the first answer is used.
    expect(await read(0x0C), 801);
    expect(await read(0x0D), 0);
    expect(await read(0x2F), 0);
    expect(await read(0xA6), closeTo(33999.7, 0.001));
  });
}
