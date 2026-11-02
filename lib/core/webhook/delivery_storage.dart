import 'dart:convert';

import '../storage/app_files.dart';
import 'queued_reading.dart';

/// What the sender keeps across restarts: the readings still to deliver,
/// oldest first, and the last sequence number used.
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

  final List<QueuedReading> queue;
  final int seq;

  /// The newest reading delivered; see `DeliveryStatus.deliveredThrough`.
  final int deliveredThrough;

  Map<String, Object?> toJson() => {
    'seq': seq,
    'deliveredThrough': deliveredThrough,
    'queue': [for (final reading in queue) reading.toJson()],
  };

  /// Also reads the earlier format, where each reading was kept as its
  /// encoded payload. Entries that don't parse are left out.
  factory DeliveryState.fromJson(Map<String, Object?> json) {
    final queue = [
      for (final entry in json['queue'] as List? ?? const []) ?_reading(entry),
    ];
    final seq = switch (json['seq']) {
      final int seq => seq,
      _ => 0,
    };
    return DeliveryState(
      queue: queue,
      seq: seq,
      deliveredThrough: switch (json['deliveredThrough']) {
        final int through => through,
        // Not kept by earlier versions: everything before the queue.
        _ => queue.isEmpty ? seq : queue.first.seq - 1,
      },
    );
  }

  static QueuedReading? _reading(Object? entry) => switch (entry) {
    final Map<String, Object?> json => QueuedReading.fromJson(json),
    final String payload => switch (_decode(payload)) {
      final Map<String, Object?> json => QueuedReading.fromJson(json),
      _ => null,
    },
    _ => null,
  };

  static Object? _decode(String source) {
    try {
      return jsonDecode(source);
    } on FormatException {
      return null;
    }
  }
}

abstract interface class DeliveryStorage {
  Future<DeliveryState> load();
  Future<void> save(DeliveryState state);
}

/// Keeps the delivery state in one file in the app's private storage,
/// written atomically so a crash can't leave a half-written queue.
class FileDeliveryStorage implements DeliveryStorage {
  static const _fileName = 'delivery.json';

  @override
  Future<DeliveryState> load() async {
    final file = await appFile(_fileName);
    if (!await file.exists()) return const DeliveryState();
    return switch (DeliveryState._decode(await file.readAsString())) {
      final Map<String, Object?> json => DeliveryState.fromJson(json),
      _ => DeliveryState.afterLoss(DateTime.now()),
    };
  }

  @override
  Future<void> save(DeliveryState state) async =>
      writeAtomically(await appFile(_fileName), jsonEncode(state.toJson()));
}
