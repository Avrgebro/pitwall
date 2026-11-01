import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/webhook/payload.dart';

void main() {
  test('payload has the documented shape', () {
    final payload = buildPayload(
      device: 'tucson',
      seq: 1284,
      timestamp: DateTime.utc(2026, 10, 31, 19, 40, 0, 123),
      values: {'fuel_level_l': 47.5, 'rpm': 800.5, 'speed_kmh': 52},
      connected: true,
    );

    expect(payload, {
      'device': 'tucson',
      'seq': 1284,
      'timestamp': '2026-10-31T19:40:00Z',
      'values': {'fuel_level_l': 47.5, 'rpm': 800.5, 'speed_kmh': 52},
      'connected': true,
    });
  });

  test('values are rounded and whole numbers lose the decimal', () {
    final values =
        buildPayload(
              device: 'x',
              seq: 1,
              timestamp: DateTime.utc(2026),
              values: {'fuel_level_pct': 46.2745098, 'coolant_temp_c': 89.0},
              connected: true,
            )['values']
            as Map;

    expect(values['fuel_level_pct'], 46.27);
    expect(values['coolant_temp_c'], isA<int>());
  });

  test('timestamps are converted to UTC', () {
    final local = DateTime.utc(2026, 10, 31, 19).toLocal();

    expect(formatTimestamp(local), '2026-10-31T19:00:00Z');
  });
}
