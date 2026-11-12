import 'dart:async';
import 'dart:convert';

import 'package:pitwall/core/obd/obd_transport.dart';

/// Plays back canned adapter replies. Commands with no reply get no answer,
/// which looks like a timeout to the caller.
class FakeTransport implements ObdTransport {
  FakeTransport(this.replies, {this.chunkSize, Map<String, Duration>? delays})
    : delays = delays ?? {};

  /// Reply text per command, without the trailing prompt.
  final Map<String, String> replies;

  /// How long the adapter takes over a command, for ones that answer late.
  /// Commands after it are answered after it.
  final Map<String, Duration> delays;

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
    void answer() {
      for (var i = 0; i < data.length; i += size) {
        final chunk = data.sublist(i, (i + size).clamp(0, data.length));
        scheduleMicrotask(() => _input.add(chunk));
      }
    }

    // Like the adapter, it answers one command at a time, in order.
    final delay = delays[command];
    _answered = _answered.then(
      (_) => delay == null ? answer() : Future.delayed(delay, answer),
    );
  }

  Future<void> _answered = Future.value();
}
