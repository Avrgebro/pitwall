import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/obd/elm327.dart';
import 'package:pitwall/core/obd/trouble_codes.dart';

import 'fake_transport.dart';

void main() {
  group('a code', () {
    test('reads its system from the first two bits', () {
      expect(troubleCode(0x01, 0x33), 'P0133');
      expect(troubleCode(0x44, 0x20), 'C0420');
      expect(troubleCode(0x91, 0x00), 'B1100');
      expect(troubleCode(0xC1, 0x55), 'U0155');
    });

    test('keeps its hex digits', () {
      expect(troubleCode(0x2A, 0xBC), 'P2ABC');
      expect(troubleCode(0x00, 0x01), 'P0001');
    });
  });

  test('CAN replies start with the count, and every module counts', () {
    expect(
      codesFrom([
        [0x02, 0x01, 0x33, 0x04, 0x20],
        [0x01, 0x01, 0x33],
        [0x00],
      ]),
      ['P0133', 'P0420'],
    );
  });

  test('older protocols pad with 0000, which is no code', () {
    expect(
      codesFrom([
        [0x01, 0x33, 0x00, 0x00, 0x00, 0x00],
      ]),
      ['P0133'],
    );
  });

  test('the light is on if any module turned it on; counts add up', () {
    expect(
      lightFrom([
        [0x00, 0x07, 0xE5, 0x00],
        [0x82, 0x07, 0xE5, 0x00],
      ]),
      (checkEngine: true, count: 2),
    );
    expect(lightFrom(const []), (checkEngine: false, count: 0));
  });

  test('reads every kind, and a kind the car refuses is none', () async {
    final elm = Elm327(
      FakeTransport({
        '0101': '41 01 81 07 E5 00',
        '03': '43 01 01 33',
        '07': '47 01 04 20',
        // Permanent codes refused: request out of range.
        '0A': '7F 0A 31',
      }),
    );

    expect(
      await readTroubleCodes(elm),
      const TroubleCodes(
        checkEngine: true,
        stored: ['P0133'],
        pending: ['P0420'],
      ),
    );
  });

  test('a round trip through JSON keeps them', () {
    const codes = TroubleCodes(
      checkEngine: true,
      stored: ['P0133'],
      pending: ['P0420'],
      permanent: ['P0133'],
    );

    expect(TroubleCodes.fromJson(codes.toJson()), codes);
  });
}
