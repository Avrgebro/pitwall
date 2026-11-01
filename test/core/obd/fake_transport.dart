import 'dart:async';
import 'dart:convert';

import 'package:pitwall/core/obd/obd_transport.dart';

/// Plays back canned adapter replies. Commands with no reply get no answer,
/// which looks like a timeout to the caller.
class FakeTransport implements ObdTransport {
  FakeTransport(this.replies, {this.chunkSize});

  /// Reply text per command, without the trailing prompt.
  final Map<String, String> replies;

  /// If set, replies are delivered in chunks of this many bytes.
  final int? chunkSize;

  final sent = <String>[];
  final _input = StreamController<List<int>>();

  @override
  Stream<List<int>> get input => _input.stream;

  /// Simulates the adapter dropping the connection.
  Future<void> disconnect() => _input.close();

  @override
  Future<void> write(List<int> bytes) async {
    final command = latin1.decode(bytes).trim();
    sent.add(command);
    final reply = replies[command];
    if (reply == null) return;
    final data = latin1.encode('$reply\r\r>');
    final size = chunkSize ?? data.length;
    for (var i = 0; i < data.length; i += size) {
      final chunk = data.sublist(i, (i + size).clamp(0, data.length));
      scheduleMicrotask(() => _input.add(chunk));
    }
  }
}
