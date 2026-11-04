import '../../core/readings/metric.dart';
import '../../core/readings/readings.dart';
import '../../ui/components/value_tile_data.dart';
import '../../core/format/formatters.dart';

/// How readings are shown: in their metrics' order, with their labels,
/// and as many decimals as read well.
abstract final class ValueDisplay {
  /// Tiles for [values], described by [options] where known, with [notes]
  /// under the values they're keyed by.
  static List<ValueTileData> tiles(
    Map<String, num> values,
    List<ValueOption> options, {
    Map<String, String> notes = const {},
  }) {
    final metrics = {
      for (final option in options) option.metric.key: option.metric,
    };
    Metric metricOf(String key) =>
        metrics[key] ?? Metric(key: key, name: key, unit: '');
    final keys = values.keys.toList()
      ..sort((a, b) {
        final byRank = metricOf(a).rank.compareTo(metricOf(b).rank);
        return byRank != 0 ? byRank : a.compareTo(b);
      });
    return [
      for (final key in keys)
        switch (metricOf(key)) {
          final metric when metric.format == MetricFormat.duration =>
            ValueTileData(
              label: metric.label,
              value: Formatters.duration(
                Duration(seconds: values[key]!.round()),
              ),
              note: notes[key],
            ),
          final metric => ValueTileData(
            label: metric.label,
            value: format(values[key]!),
            unit: metric.unit.isEmpty ? null : metric.unit,
            note: notes[key],
          ),
        },
    ];
  }

  /// One decimal for small values; none from 1,000 up (`33,999 km`).
  static String format(num value) =>
      Formatters.number(value, decimals: value.abs() >= 1000 ? 0 : 1);
}
