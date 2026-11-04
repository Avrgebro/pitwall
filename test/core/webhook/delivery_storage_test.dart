import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/webhook/delivery_storage.dart';
import 'package:pitwall/core/webhook/queued_reading.dart';

import '../../helpers/temporary_app_files.dart';

void main() {
  final reading = QueuedReading(
    seq: 7,
    device: 'hyundai-tucson',
    timestamp: DateTime.utc(2026, 11, 2, 0, 30),
    values: const {'odometer_km': 33999.7, 'battery_v': 14.1},
    connected: true,
    engineRunning: true,
  );

  test('a round trip keeps the queue, the sequence and what was delivered', () {
    final state = DeliveryState(queue: [reading], seq: 7, deliveredThrough: 5);
    final back = DeliveryState.fromJson(
      jsonDecode(jsonEncode(state.toJson())) as Map<String, Object?>,
    );

    expect(back.seq, 7);
    expect(back.deliveredThrough, 5);
    expect(back.queue.single.toJson(), reading.toJson());
  });

  test('after a loss, numbering resumes above anything before', () {
    final state = DeliveryState.afterLoss(DateTime.utc(2026, 11, 2));
    expect(state.seq, greaterThan(1000000000));
    expect(state.deliveredThrough, state.seq);
  });

  test('a reading is stored at full precision, apart from its payload', () {
    final precise = QueuedReading(
      seq: 8,
      device: 'hyundai-tucson',
      timestamp: DateTime.utc(2026, 11, 2),
      values: const {'battery_v': 14.123456},
      connected: true,
    );

    final back = DeliveryState.fromJson(
      jsonDecode(jsonEncode(DeliveryState(queue: [precise]).toJson()))
          as Map<String, Object?>,
    );

    expect(back.queue.single.values['battery_v'], 14.123456);
  });

  test('what goes out is the payload itself', () {
    expect(reading.toPayload(), {
      'device': 'hyundai-tucson',
      'seq': 7,
      'timestamp': '2026-11-02T00:30:00Z',
      'values': {'odometer_km': 33999.7, 'battery_v': 14.1},
      'engine': 'running',
      'connected': true,
    });
  });

  group('the file', () {
    late File file;
    setUp(() => file = File('${useTemporaryAppFiles().path}/delivery.json'));

    test('a round trip through it keeps the state', () async {
      final storage = FileDeliveryStorage();
      await storage.save(DeliveryState(queue: [reading], seq: 7));

      final back = await storage.load();

      expect(back.seq, 7);
      expect(back.queue.single.toJson(), reading.toJson());
    });

    test(
      'saved before versions, with payloads, is brought up to date',
      () async {
        file.writeAsStringSync(
          jsonEncode({
            'seq': 7,
            'deliveredThrough': 6,
            'queue': [reading.toPayload()],
          }),
        );

        final state = await FileDeliveryStorage().load();

        expect(state.seq, 7);
        expect(state.deliveredThrough, 6);
        expect(state.queue.single.values, {
          'odometer_km': 33999.7,
          'battery_v': 14.1,
        });
        expect(state.queue.single.engineRunning, isTrue);
      },
    );

    test(
      'version 2, with the fields beside the version, still loads',
      () async {
        file.writeAsStringSync(
          jsonEncode({
            ...DeliveryState(queue: [reading], seq: 7).toJson(),
            'version': 2,
          }),
        );

        final state = await FileDeliveryStorage().load();

        expect(state.seq, 7);
        expect(state.queue.single.toJson(), reading.toJson());
      },
    );

    test('missing, broken, or from a newer version, is a lost state', () async {
      for (final source in [
        null,
        'garbage',
        '{"version": 99, "data": {"seq": 7}}',
        '{"version": 3, "data": "not a state"}',
      ]) {
        if (source != null) file.writeAsStringSync(source);
        final before = DateTime.now().millisecondsSinceEpoch;

        final state = await FileDeliveryStorage().load();

        expect(state.seq, greaterThanOrEqualTo(before), reason: source);
      }
    });
  });

  test('a queue that isn\'t a list loads as empty', () {
    final back = DeliveryState.fromJson({'seq': 7, 'queue': 'broken'});

    expect(back.queue, isEmpty);
    expect(back.seq, 7);
  });
}
