import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/webhook/delivery_storage.dart';
import 'package:pitwall/core/webhook/queued_reading.dart';

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

  test('without what was delivered, it\'s everything before the queue', () {
    expect(
      DeliveryState.fromJson({
        'seq': 7,
        'queue': [reading.toJson()],
      }).deliveredThrough,
      6,
    );
    expect(DeliveryState.fromJson({'seq': 7}).deliveredThrough, 7);
  });

  test('after a loss, numbering resumes above anything before', () {
    final state = DeliveryState.afterLoss(DateTime.utc(2026, 11, 2));
    expect(state.seq, greaterThan(1000000000));
    expect(state.deliveredThrough, state.seq);
  });

  test('the earlier format, payloads as text, still loads', () {
    final payload = jsonEncode(reading.toJson());
    final back = DeliveryState.fromJson({
      'seq': 7,
      'queue': [payload, 'not json'],
      'lastReading': payload,
    });

    expect(back.queue.single.seq, 7);
    expect(back.queue.single.values, {
      'odometer_km': 33999.7,
      'battery_v': 14.1,
    });
    expect(back.queue.single.engineRunning, isTrue);
  });

  test('what goes out is the payload itself', () {
    expect(reading.toJson(), {
      'device': 'hyundai-tucson',
      'seq': 7,
      'timestamp': '2026-11-02T00:30:00Z',
      'values': {'odometer_km': 33999.7, 'battery_v': 14.1},
      'engine': 'running',
      'connected': true,
    });
  });

  test('a queue that isn\'t a list loads as empty', () {
    final back = DeliveryState.fromJson({'seq': 7, 'queue': 'broken'});

    expect(back.queue, isEmpty);
    expect(back.seq, 7);
  });
}
