import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/logging/adapter_log.dart';
import 'package:pitwall/core/obd/elm327.dart';

void main() {
  test('an exchange reads as one line, and warns as the adapter said', () {
    final log = AdapterLog(clock: () => DateTime(2026, 11, 2, 10, 4, 5));

    log.exchange('010C', '7E8 41 0C 1A F8\r7E9 41 0C 1A F0\r\r>', null);
    log.exchange('010D', 'NO DATA\r\r>', ElmError.noData);
    log.note('Car answered');

    final [reply, noData, note] = log.entries.value;
    expect(reply.trail, '← 7E8 41 0C 1A F8 7E9 41 0C 1A F0');
    expect(reply.warning, isFalse);
    expect(noData.warning, isTrue);
    expect(note.lead, '- Car answered');
    expect(
      log.asText().split('\n').first,
      endsWith('→ 010C ← 7E8 41 0C 1A F8 7E9 41 0C 1A F0'),
    );
  });
}
