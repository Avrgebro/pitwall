import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/readings/readings.dart';
import 'package:pitwall/features/home/value_display.dart';

void main() {
  test('run time reads as a duration, other values with their unit', () {
    final tiles = ValueDisplay.tiles({
      'engine_run_time_s': 1420,
      'speed_kmh': 52,
    }, valueOptions(null, null));

    final runTime = tiles.firstWhere((t) => t.label == 'Run time');
    expect(runTime.value, '23 min');
    expect(runTime.unit, isNull);
    expect(tiles.firstWhere((t) => t.label == 'Speed').unit, 'km/h');
  });
}
