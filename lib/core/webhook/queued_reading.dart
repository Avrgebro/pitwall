import 'package:flutter/foundation.dart';

import '../obd/trouble_codes.dart';
import 'payload.dart';

/// A reading waiting to be sent, kept as data and encoded only when
/// posted. Stored in a shape of its own, at full precision, so the webhook
/// payload can change without changing what's on disk.
@immutable
class QueuedReading {
  const QueuedReading({
    required this.seq,
    required this.device,
    required this.timestamp,
    required this.values,
    required this.connected,
    this.engineRunning,
    this.troubleCodes,
  });

  final int seq;
  final String device;
  final DateTime timestamp;
  final Map<String, double> values;
  final bool connected;
  final bool? engineRunning;

  /// The trouble codes as last read, and when, if the vehicle sends them.
  final TroubleCodesRead? troubleCodes;

  /// The JSON body to post.
  Map<String, Object?> toPayload() => buildPayload(
    device: device,
    seq: seq,
    timestamp: timestamp,
    values: values,
    connected: connected,
    engineRunning: engineRunning,
    troubleCodes: troubleCodes,
  );

  Map<String, Object?> toJson() => {
    'seq': seq,
    'device': device,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'values': values,
    'connected': connected,
    'engineRunning': engineRunning,
    'troubleCodes': ?troubleCodes?.codes.toJson(),
    'troubleCodesAt': ?troubleCodes?.at.toUtc().toIso8601String(),
  };

  /// Null if [json] isn't a stored reading.
  static QueuedReading? fromJson(Map<String, Object?> json) {
    if (json case {
      'seq': final int seq,
      'device': final String device,
      'timestamp': final String timestamp,
      'values': final Map<String, Object?> values,
      'connected': final bool connected,
    }) {
      final time = DateTime.tryParse(timestamp);
      if (time == null) return null;
      return QueuedReading(
        seq: seq,
        device: device,
        timestamp: time,
        values: {
          for (final MapEntry(:key, :value) in values.entries)
            if (value is num) key: value.toDouble(),
        },
        connected: connected,
        engineRunning: switch (json['engineRunning']) {
          final bool running => running,
          _ => null,
        },
        troubleCodes: switch (json['troubleCodes']) {
          final Map<String, Object?> codes => (
            codes: TroubleCodes.fromJson(codes),
            // Queued before the time was kept: no later than the reading.
            at: switch (json['troubleCodesAt']) {
              final String at => DateTime.tryParse(at) ?? time,
              _ => time,
            },
          ),
          _ => null,
        },
      );
    }
    return null;
  }
}
