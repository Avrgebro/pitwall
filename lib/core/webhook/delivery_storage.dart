import 'dart:convert';

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

  /// After the saved state was lost: numbering resumes above anything it
  /// could have reached, so readings keep going up for the receiver, and
  /// numbers kept elsewhere, as with the last values, still read right.
  DeliveryState.afterLoss(DateTime now)
    : this(
        seq: now.millisecondsSinceEpoch,
        deliveredThrough: now.millisecondsSinceEpoch,
      );

  /// The format [toJson] writes; see `FileDeliveryStorage.load`.
  static const version = 2;

  final List<QueuedReading> queue;
  final int seq;

  /// The newest reading delivered; see `DeliveryStatus.deliveredThrough`.
  final int deliveredThrough;

  Map<String, Object?> toJson() => {
    'version': version,
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
  Future<DeliveryState> load();
  Future<void> save(DeliveryState state);
}

/// Keeps the delivery state in one file in the app's private storage,
/// written atomically so a crash can't leave a half-written queue.
class FileDeliveryStorage implements DeliveryStorage {
  static const _fileName = 'delivery.json';

  /// A file that's gone, can't be read or doesn't parse is a lost state:
  /// numbering resumes above anything before, which a first start needs no
  /// less. Earlier formats are brought up to date here, and only here.
  @override
  Future<DeliveryState> load() async =>
      decode(await readJsonFile(_fileName), now: DateTime.now());

  /// What the file's JSON, or its absence, means; see [load].
  static DeliveryState decode(Object? json, {required DateTime now}) =>
      switch (json) {
        final Map<String, Object?> json => switch (json['version']) {
          DeliveryState.version => DeliveryState.fromJson(json),
          null => DeliveryState._read(json, _readingFromPayload),
          _ => DeliveryState.afterLoss(now),
        },
        _ => DeliveryState.afterLoss(now),
      };

  @override
  Future<void> save(DeliveryState state) async =>
      writeAtomically(await appFile(_fileName), jsonEncode(state.toJson()));

  /// Version 1 kept each reading as its webhook payload.
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
