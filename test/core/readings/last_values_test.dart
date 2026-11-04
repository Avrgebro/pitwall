import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/readings/last_values.dart';
import 'package:pitwall/core/readings/unreported.dart';

void main() {
  final earlier = DateTime.utc(2026, 11, 2, 0, 25);
  final later = DateTime.utc(2026, 11, 2, 0, 31);

  test('a reading replaces only the keys it carries', () {
    final values = const LastValues()
        .record(
          'tucson',
          {'odometer_km': 33999.7, 'battery_v': 14.1},
          earlier,
          seq: 1,
        )
        .record('tucson', {'battery_v': 12.4}, later, seq: 1);

    expect(values.of('tucson'), {
      'odometer_km': LastValue(33999.7, earlier, seq: 1),
      'battery_v': LastValue(12.4, later, seq: 1),
    });
  });

  test('vehicles are kept apart and can be forgotten', () {
    final values = const LastValues()
        .record('tucson', {'rpm': 800}, earlier, seq: 1)
        .record('mazda', {'rpm': 900}, later, seq: 1);

    expect(values.of('tucson')['rpm']!.value, 800);
    expect(values.only({'mazda'}).of('tucson'), isEmpty);
    expect(values.only({'mazda'}).of('mazda')['rpm']!.value, 900);
  });

  test('a round trip through JSON keeps values and times', () {
    final values = const LastValues().record(
      'tucson',
      {'odometer_km': 33999.7, 'battery_v': 12},
      later,
      seq: 1,
    );

    expect(
      LastValues.fromJson(values.toJson()).of('tucson'),
      values.of('tucson'),
    );
  });

  test('broken entries are left out', () {
    final values = LastValues.fromValuesJson({
      'tucson': {
        'battery_v': {'value': 12.4, 'at': later.toIso8601String(), 'seq': 1},
        'coolant_temp_c': {'value': 90, 'at': later.toIso8601String()},
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

  test('sent values are the chosen ones, with the newest', () {
    final earlier = DateTime(2026, 11, 2, 9);
    final later = DateTime(2026, 11, 2, 10);
    final kept = const LastValues()
        .record('tucson', {'rpm': 800}, earlier, seq: 1)
        .record('tucson', {'speed_kmh': 50}, later, seq: 2);

    final (values: sent, :newest) = kept.sentOf('tucson', {'rpm'});

    expect(sent.keys, ['rpm']);
    expect(newest?.readAt, earlier);
  });

  test('values asked for and not reported are kept until they come', () {
    final missing = const LastValues().record(
      'tucson',
      {'rpm': 800},
      earlier,
      seq: 1,
      missing: {'tucson_aux_soc': Unreported.notInReply},
    );
    expect(missing.unreportedOf('tucson'), {
      'tucson_aux_soc': UnreportedValue(Unreported.notInReply, earlier),
    });

    // Kept through JSON, as written to the file.
    final back = LastValues.fromJson(missing.toJson());
    expect(back.unreportedOf('tucson'), missing.unreportedOf('tucson'));
    expect(back.of('tucson')['rpm']?.value, 800);

    final arrived = back.record(
      'tucson',
      {'tucson_aux_soc': 80},
      later,
      seq: 2,
    );
    expect(arrived.unreportedOf('tucson'), isEmpty);
  });

  test('a reading with nothing to send still notes what didn\'t come', () {
    final values = const LastValues().noteUnreported('tucson', {
      'rpm': Unreported.noAnswer,
    }, later);

    expect(values.of('tucson'), isEmpty);
    expect(values.unreportedOf('tucson')['rpm']?.reason, Unreported.noAnswer);
  });
}
