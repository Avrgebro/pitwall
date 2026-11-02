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

  test('a round trip keeps the queue, the sequence and the latest', () {
    final state = DeliveryState(queue: [reading], seq: 7, latest: reading);
    final back = DeliveryState.fromJson(
      jsonDecode(jsonEncode(state.toJson())) as Map<String, Object?>,
    );

    expect(back.seq, 7);
    expect(back.queue.single.toJson(), reading.toJson());
    expect(back.latest!.toJson(), reading.toJson());
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
    expect(back.latest!.device, 'hyundai-tucson');
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
}
