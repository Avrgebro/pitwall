import '../../core/readings/readings.dart';
import '../../ui/components/value_tile.dart';
import '../../ui/format/formatters.dart';

/// How readings are shown: which order, which labels, how many decimals.
abstract final class ValueDisplay {
  /// Most glanceable first; the odometer last, where it gets a full row.
  static const _order = [
    'fuel_level_pct',
    batteryVoltageKey,
    'coolant_temp_c',
    'speed_kmh',
    'rpm',
    'engine_run_time_s',
  ];
  static const _last = 'odometer_km';

  /// Tiles for [values], labelled with [options] where known, with
  /// [notes] under the values they're keyed by.
  static List<ValueTileData> tiles(
    Map<String, num> values,
    List<ValueOption> options, {
    Map<String, String> notes = const {},
  }) {
    final byKey = {for (final option in options) option.key: option};
    int rank(String key) {
      if (key == _last) return 1000;
      final index = _order.indexOf(key);
      return index == -1 ? _order.length : index;
    }

    final keys = values.keys.toList()
      ..sort((a, b) {
        final byRank = rank(a).compareTo(rank(b));
        return byRank != 0 ? byRank : a.compareTo(b);
      });
    return [
      for (final key in keys)
        // Seconds read better as a duration ("24 min"); the payload keeps
        // seconds.
        if (key == _runTime)
          ValueTileData(
            label: byKey[key]?.shortName ?? key,
            value: Formatters.duration(Duration(seconds: values[key]!.round())),
            note: notes[key],
          )
        else
          ValueTileData(
            label: byKey[key]?.shortName ?? key,
            value: format(values[key]!),
            unit: byKey[key]?.unit,
            note: notes[key],
          ),
    ];
  }

  static const _runTime = 'engine_run_time_s';

  /// One decimal for small values; none from 1,000 up (`33,999 km`).
  static String format(num value) =>
      Formatters.number(value, decimals: value.abs() >= 1000 ? 0 : 1);
}
