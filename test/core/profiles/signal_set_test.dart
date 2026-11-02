import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/profiles/signal_set.dart';

import 'test_profile.dart';

void main() {
  group('parsing', () {
    final signalSet = SignalSet.parse(testProfileJson);

    test('keeps read requests and skips everything else', () {
      expect(signalSet.commands.map((c) => c.id), [
        [0x12, 0x34],
        [0x00, 0x42],
      ]);
      expect(signalSet.skipped.map((s) => s.reason), [
        SkipReason.notReadOnly,
        SkipReason.notReadOnly,
        SkipReason.notReadOnly,
        SkipReason.extendedAddress,
        SkipReason.specialFlowControl,
      ]);
    });

    test('year filters pick the matching commands', () {
      expect(signalSet.commandsFor(2023).map((c) => c.header), ['7A0']);
      expect(signalSet.commandsFor(2018).map((c) => c.header), ['7A0', '7E0']);
    });

    test('signals keep their id, in lower case, and their unit', () {
      final signals = signalSet.commands.first.signals;

      // Even with OBDb's suggestedMetric tags, nothing is renamed.
      expect(signals.map((s) => s.key), ['test_fuel_vol', 'test_odo_mi']);
      expect(signals.map((s) => s.unit), ['liters', 'miles']);
      expect(signalSet.commands.last.signals.single.key, 'test_old_only');
    });

    test('rejects files that are not signal sets', () {
      expect(() => SignalSet.parse('not json'), throwsFormatException);
      expect(() => SignalSet.parse('{"ecu": []}'), throwsFormatException);
    });
  });

  group('decoding', () {
    test('big-endian bytes with scaling', () {
      const format = SignalFormat(bitIndex: 8, bitLength: 16, divide: 4);

      expect(format.decode([0xFF, 0x1A, 0xF8]), 1726);
    });

    test('little-endian bytes', () {
      const format = SignalFormat(
        bitIndex: 8,
        bitLength: 16,
        littleEndian: true,
        divide: 10,
      );

      expect(format.decode([0x00, 0xCD, 0x00]), 20.5);
    });

    test('bit fields that do not start on a byte', () {
      const format = SignalFormat(bitIndex: 4, bitLength: 3);

      expect(format.decode([0x0A]), 5); // 0000 1010 -> bits 4-6 are 101
    });

    test('signed values with an offset', () {
      const format = SignalFormat(
        bitIndex: 0,
        bitLength: 8,
        signed: true,
        add: 1,
      );

      expect(format.decode([0xFE]), -1);
    });

    test('null markers and short replies give no value', () {
      const format = SignalFormat(
        bitIndex: 0,
        bitLength: 8,
        divide: 2,
        nullMax: 127.5,
      );

      expect(format.decode([0xFF]), isNull);
      expect(format.decode([]), isNull);
    });

    test('values outside the valid range give no value', () {
      // Recorded: an unsupported field filled with FF bytes.
      const format = SignalFormat(
        bitIndex: 0,
        bitLength: 16,
        littleEndian: true,
        divide: 10,
        max: 6553,
      );

      expect(format.decode([0xFF, 0xFF]), isNull);
      expect(format.decode([0xCD, 0x00]), 20.5);
    });

    test('values stay in the profile\'s units', () {
      final odometer = SignalSet.parse(testProfileJson)
          .commands
          .first
          .signals
          .last;

      expect(odometer.unit, 'miles');
      expect(odometer.decode([0x00, 0x00, 0x00, 0x32, 0xF2]), 13042);
    });
  });
}
