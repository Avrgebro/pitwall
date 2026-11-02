import 'dart:convert';

import '../storage/app_files.dart';

/// What the sender keeps across restarts: the payloads still to deliver,
/// oldest first, the last sequence number used, and the newest payload that
/// carried values (shown on Home).
class DeliveryState {
  const DeliveryState({this.queue = const [], this.seq = 0, this.lastReading});

  /// Encoded JSON bodies, ready to POST.
  final List<String> queue;
  final int seq;

  /// The newest payload with values. End-of-trip messages carry none, so
  /// they never replace it.
  final String? lastReading;
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
    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, Object?>;
      return DeliveryState(
        queue: [...(json['queue'] as List? ?? const []).whereType<String>()],
        seq: (json['seq'] as num? ?? 0).toInt(),
        lastReading: json['lastReading'] as String?,
      );
    } on Object {
      return const DeliveryState();
    }
  }

  @override
  Future<void> save(DeliveryState state) async => writeAtomically(
    await appFile(_fileName),
    jsonEncode({
      'seq': state.seq,
      'queue': state.queue,
      'lastReading': state.lastReading,
    }),
  );
}
