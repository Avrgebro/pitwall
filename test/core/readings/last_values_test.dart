import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/readings/last_values.dart';

void main() {
  final earlier = DateTime.utc(2026, 11, 2, 0, 25);
  final later = DateTime.utc(2026, 11, 2, 0, 31);

  test('a reading replaces only the keys it carries', () {
    final values = const LastValues()
        .record('tucson', {'odometer_km': 33999.7, 'battery_v': 14.1}, earlier)
        .record('tucson', {'battery_v': 12.4}, later);

    expect(values.of('tucson'), {
      'odometer_km': LastValue(33999.7, earlier),
      'battery_v': LastValue(12.4, later),
    });
  });

  test('vehicles are kept apart and can be forgotten', () {
    final values = const LastValues()
        .record('tucson', {'rpm': 800}, earlier)
        .record('mazda', {'rpm': 900}, later);

    expect(values.of('tucson')['rpm']!.value, 800);
    expect(values.without('tucson').of('tucson'), isEmpty);
    expect(values.without('tucson').of('mazda')['rpm']!.value, 900);
  });

  test('a round trip through JSON keeps values and times', () {
    final values = const LastValues().record('tucson', {
      'odometer_km': 33999.7,
      'battery_v': 12,
    }, later);

    expect(
      LastValues.fromJson(values.toJson()).of('tucson'),
      values.of('tucson'),
    );
  });

  test('broken entries are left out', () {
    final values = LastValues.fromJson({
      'tucson': {
        'battery_v': {'value': 12.4, 'at': later.toIso8601String()},
        'rpm': {'value': 'fast', 'at': later.toIso8601String()},
        'speed_kmh': {'value': 50, 'at': 'yesterday'},
      },
      'mazda': 'not a map',
    });

    expect(values.of('tucson').keys, ['battery_v']);
    expect(values.of('mazda'), isEmpty);
  });

  test('each value keeps the number of the reading it went out in', () {
    final values = const LastValues().record(
      'tucson',
      {'battery_v': 12.4},
      later,
      seq: 42,
    );

    final back = LastValues.fromJson(values.toJson()).of('tucson');
    expect(back['battery_v']!.seq, 42);
  });
}
