import 'package:flutter/foundation.dart';

import 'payload.dart';

/// A reading waiting to be sent, kept as data and encoded only when
/// posted. Stored in the payload's own shape, so queues saved as payloads
/// by earlier versions read back the same way.
@immutable
class QueuedReading {
  const QueuedReading({
    required this.seq,
    required this.device,
    required this.timestamp,
    required this.values,
    required this.connected,
    this.engineRunning,
  });

  final int seq;
  final String device;
  final DateTime timestamp;
  final Map<String, double> values;
  final bool connected;
  final bool? engineRunning;

  /// The JSON body to post; also how it's stored.
  Map<String, Object?> toJson() => buildPayload(
    device: device,
    seq: seq,
    timestamp: timestamp,
    values: values,
    connected: connected,
    engineRunning: engineRunning,
  );

  /// Null if [json] isn't a payload.
  static QueuedReading? fromJson(Map<String, Object?> json) {
    if (json case {
      'seq': final int seq,
      'device': final String device,
      'timestamp': final String timestamp,
      'connected': final bool connected,
    }) {
      final time = DateTime.tryParse(timestamp);
      if (time == null) return null;
      return QueuedReading(
        seq: seq,
        device: device,
        timestamp: time,
        values: {
          if (json['values'] case final Map<String, Object?> values)
            for (final MapEntry(:key, :value) in values.entries)
              if (value is num) key: value.toDouble(),
        },
        connected: connected,
        engineRunning: switch (json['engine']) {
          'running' => true,
          'off' => false,
          _ => null,
        },
      );
    }
    return null;
  }
}
