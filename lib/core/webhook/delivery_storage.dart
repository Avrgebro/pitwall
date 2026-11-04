import '../storage/app_files.dart';
import 'queued_reading.dart';

/// What the sender keeps across restarts: the readings still to deliver,
/// oldest first, the last sequence number used, and the newest delivered.
class DeliveryState {
  const DeliveryState({
    this.queue = const [],
    this.seq = 0,
    this.deliveredThrough = 0,
  });

  /// With nothing saved, or nothing readable: everything numbered before
  /// [now] counts as delivered, so numbers kept elsewhere, as with the last
  /// values, still read right. Numbering itself never goes back anyway;
  /// see `WebhookSender.queue`.
  DeliveryState.afterLoss(DateTime now)
    : this(deliveredThrough: now.millisecondsSinceEpoch);

  final List<QueuedReading> queue;
  final int seq;

  /// The newest reading delivered; see `DeliveryStatus.deliveredThrough`.
  final int deliveredThrough;

  Map<String, Object?> toJson() => {
    'seq': seq,
    'deliveredThrough': deliveredThrough,
    'queue': [for (final reading in queue) reading.toJson()],
  };

  /// Reads the current format. Readings that don't parse are left out.
  factory DeliveryState.fromJson(Map<String, Object?> json) =>
      _read(json, QueuedReading.fromJson);

  static DeliveryState _read(
    Map<String, Object?> json,
    QueuedReading? Function(Map<String, Object?> json) reading,
  ) => DeliveryState(
    queue: [
      if (json['queue'] case final List<Object?> queue)
        for (final entry in queue)
          if (entry is Map<String, Object?>) ?reading(entry),
    ],
    seq: switch (json['seq']) {
      final int seq => seq,
      _ => 0,
    },
    deliveredThrough: switch (json['deliveredThrough']) {
      final int through => through,
      _ => 0,
    },
  );
}

abstract interface class DeliveryStorage {
  /// The saved state, or null if there's none, or none readable.
  Future<DeliveryState?> load();
  Future<void> save(DeliveryState state);
}

/// Keeps the delivery state in one file in the app's private storage,
/// written atomically so a crash can't leave a half-written queue.
class FileDeliveryStorage implements DeliveryStorage {
  static const _fileName = 'delivery.json';

  /// The format [save] writes.
  static const _version = 3;

  @override
  Future<DeliveryState?> load() => readVersionedFile(_fileName, {
    // Before versions, each reading was kept as its webhook payload.
    0: (json) => DeliveryState._read(json, _readingFromPayload),
    2: DeliveryState.fromJson,
    _version: (json) => switch (dataOf(json)) {
      final data? => DeliveryState.fromJson(data),
      null => null,
    },
  });

  @override
  Future<void> save(DeliveryState state) =>
      writeVersionedFile(_fileName, _version, state.toJson());

  /// A reading kept as its webhook payload.
  static QueuedReading? _readingFromPayload(Map<String, Object?> json) {
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
