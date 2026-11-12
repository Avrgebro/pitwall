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
        '0101': '41018107E500',
        '03': '43010133',
        '07': '47010420',
        // Permanent codes refused: request out of range.
        '0A': '7F0A31',
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

  group('a connection\'s reader', () {
    final start = DateTime(2026, 11, 12, 9);
    late FakeTransport adapter;
    late TroubleCodesReader reader;
    setUp(() {
      adapter = FakeTransport({
        '0101': '410100076500',
        '03': '4300',
        '07': '4700',
        '0A': '4A00',
      });
      reader = TroubleCodesReader();
    });

    test('reads them all first, then only the light', () async {
      final elm = Elm327(adapter);

      final first = await reader.read(elm, start);
      final second = await reader.read(
        elm,
        start.add(const Duration(minutes: 1)),
      );

      expect(first.changed, isTrue);
      expect(second.changed, isFalse);
      // Still as read the first time.
      expect(second.read.at, start);
      expect(adapter.sent.where((c) => c == '03'), hasLength(1));
      expect(adapter.sent.where((c) => c == '0101'), hasLength(2));
    });

    test('reads them all again when the count changes', () async {
      final elm = Elm327(adapter);
      await reader.read(elm, start);
      adapter.replies
        ..['0101'] = '410181076500'
        ..['03'] = '43010133';

      final later = start.add(const Duration(minutes: 1));
      final read = await reader.read(elm, later);

      expect(read.changed, isTrue);
      expect(read.read.codes.stored, ['P0133']);
      expect(read.read.at, later);
    });

    test('reads them all again after a while, for new pending ones', () async {
      final elm = Elm327(adapter);
      await reader.read(elm, start);
      adapter.replies['07'] = '47010420';

      final read = await reader.read(
        elm,
        start.add(TroubleCodesReader.rereadAfter),
      );

      expect(read.read.codes.pending, ['P0420']);
    });

    test('keeps what it knew when a read fails', () async {
      final elm = Elm327(adapter);
      await reader.read(elm, start);
      adapter.replies['0101'] = '?';

      await expectLater(
        reader.read(elm, start.add(const Duration(minutes: 1))),
        throwsA(isA<ElmException>()),
      );
      expect(reader.known?.at, start);
    });
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
