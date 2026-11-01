/// Builds the JSON body sent to the webhook, as documented in the README.
///
/// Values are rounded to two decimals, and whole numbers are sent without
/// a decimal point (`52`, not `52.0`).
Map<String, Object?> buildPayload({
  required String device,
  required int seq,
  required DateTime timestamp,
  required Map<String, double> values,
  required bool connected,
}) => {
  'device': device,
  'seq': seq,
  'timestamp': formatTimestamp(timestamp),
  'values': {
    for (final MapEntry(:key, :value) in values.entries) key: _round(value),
  },
  'connected': connected,
};

/// UTC, to the second, like `2026-10-31T19:40:00Z`.
String formatTimestamp(DateTime time) {
  final utc = time.toUtc();
  return DateTime.utc(
    utc.year,
    utc.month,
    utc.day,
    utc.hour,
    utc.minute,
    utc.second,
  ).toIso8601String().replaceFirst('.000Z', 'Z');
}

num _round(double value) {
  final rounded = (value * 100).roundToDouble() / 100;
  return rounded == rounded.truncateToDouble() ? rounded.toInt() : rounded;
}
