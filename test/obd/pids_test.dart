import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/obd/pids.dart';

double decode(int pid, List<int> data) => standardPidsById[pid]!.decode(data);

void main() {
  test('coolant temperature is offset by 40', () {
    expect(decode(0x05, [0x81]), 89);
  });

  test('rpm is two bytes divided by 4', () {
    expect(decode(0x0C, [0x1A, 0xF8]), 1726);
  });

  test('speed is one byte in km/h', () {
    expect(decode(0x0D, [0x34]), 52);
  });

  test('fuel level is a fraction of 255', () {
    expect(decode(0x2F, [0x76]), closeTo(46.27, 0.01));
  });

  test('odometer is four bytes in tenths of a km', () {
    expect(decode(0xA6, [0x00, 0x02, 0xD0, 0x40]), 18438.4);
  });

  test('payload keys are unique', () {
    final keys = standardPids.map((d) => d.key);
    expect(keys.toSet().length, keys.length);
  });
}
