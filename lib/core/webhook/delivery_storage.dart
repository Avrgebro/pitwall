import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// What the sender keeps across restarts: the payloads still to deliver,
/// oldest first, the last sequence number used, and the last payload
/// delivered (shown as "last values sent").
class DeliveryState {
  const DeliveryState({
    this.queue = const [],
    this.seq = 0,
    this.lastDelivered,
  });

  /// Encoded JSON bodies, ready to POST.
  final List<String> queue;
  final int seq;
  final String? lastDelivered;
}

abstract interface class DeliveryStorage {
  Future<DeliveryState> load();
  Future<void> save(DeliveryState state);
}

/// Keeps the delivery state in one file in the app's private storage.
/// Writes go to a temporary file first, so a crash mid-write can't leave a
/// half-written queue behind.
class FileDeliveryStorage implements DeliveryStorage {
  static const _fileName = 'delivery.json';

  @override
  Future<DeliveryState> load() async {
    final file = await _file();
    if (!await file.exists()) return const DeliveryState();
    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, Object?>;
      return DeliveryState(
        queue: [...(json['queue'] as List? ?? const []).whereType<String>()],
        seq: (json['seq'] as num? ?? 0).toInt(),
        lastDelivered: json['lastDelivered'] as String?,
      );
    } on Object {
      return const DeliveryState();
    }
  }

  @override
  Future<void> save(DeliveryState state) async {
    final file = await _file();
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({
        'seq': state.seq,
        'queue': state.queue,
        'lastDelivered': state.lastDelivered,
      }),
      flush: true,
    );
    await temporary.rename(file.path);
  }

  Future<File> _file() async =>
      File('${(await getApplicationSupportDirectory()).path}/$_fileName');
}
