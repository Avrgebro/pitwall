import 'dart:async';
import 'dart:convert';

import 'obd_transport.dart';
import 'pids.dart';

enum ElmError {
  /// The car didn't answer this request, usually because it doesn't support it.
  noData,

  /// The adapter didn't understand the command (`?`).
  unknownCommand,

  /// The adapter couldn't talk to the car, e.g. because the ignition is off.
  unableToConnect,

  /// The OBD bus reported a problem (`CAN ERROR`, `BUS INIT: ...ERROR`, etc.).
  busError,

  /// The adapter stopped the request because it received input mid-reply.
  stopped,

  /// No `>` prompt arrived in time.
  timeout,
}

class ElmException implements Exception {
  ElmException(this.error, this.command, [this.response = '']);

  final ElmError error;
  final String command;
  final String response;

  @override
  String toString() => 'ElmException(${error.name}, $command): $response';
}

/// Talks to an ELM327 adapter (or a compatible clone) over an [ObdTransport].
///
/// Commands are sent one at a time; concurrent calls to [send] are queued.
/// After an [ElmError.timeout] the adapter may still be answering the old
/// command, so callers should run [initialize] again before continuing.
class Elm327 {
  Elm327(this._transport) {
    _subscription = _transport.input.listen(_onData);
  }

  static const defaultTimeout = Duration(seconds: 3);
  static const resetTimeout = Duration(seconds: 5);

  /// The first OBD request after `ATSP0` makes the adapter search for the
  /// car's protocol, which can take several seconds.
  static const searchTimeout = Duration(seconds: 15);

  static final _busInitOk = RegExp(r'^BUS INIT:.*OK$');
  static final _busError = RegExp(
    r'^(CAN ERROR|BUS ERROR|BUS BUSY|FB ERROR|DATA ERROR|BUFFER FULL|'
    r'LV RESET|ERR\d+|BUS INIT:.*ERROR)$',
  );
  static final _voltage = RegExp(r'(\d+(?:\.\d+)?)\s*V');

  final ObdTransport _transport;
  late final StreamSubscription<List<int>> _subscription;
  final _buffer = StringBuffer();
  Completer<String>? _pending;
  Future<void> _queue = Future.value();

  /// Resets the adapter and configures it for compact, header-free replies
  /// with automatic protocol detection. Returns the adapter's banner, such as
  /// `ELM327 v1.5`.
  Future<String> initialize() async {
    final banner = await send('ATZ', timeout: resetTimeout);
    for (final command in ['ATE0', 'ATL0', 'ATS0', 'ATH0', 'ATSP0']) {
      await send(command);
    }
    return banner.split('\n').last;
  }

  /// Sends [command] and returns the reply without the echo, the prompt,
  /// blank lines and status lines like `SEARCHING...`.
  ///
  /// Throws [ElmException] if the adapter reports an error or times out.
  Future<String> send(String command, {Duration timeout = defaultTimeout}) {
    final result = _queue.then((_) => _exchange(command, timeout));
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// Asks the car which mode 01 PIDs it supports, across all its ECUs.
  ///
  /// Meant to be the first OBD request after [initialize], so it allows time
  /// for protocol detection.
  Future<Set<int>> supportedPids() async {
    final supported = <int>{};
    for (var base = 0x00; base <= 0xE0; base += 0x20) {
      final replies = await _mode01(
        base,
        timeout: base == 0 ? searchTimeout : defaultTimeout,
      );
      for (final data in replies) {
        if (data.length < 4) continue;
        for (var i = 0; i < 32; i++) {
          if (data[i ~/ 8] & (0x80 >> (i % 8)) != 0) {
            supported.add(base + i + 1);
          }
        }
      }
      // The last bit of each range says whether the next range exists.
      if (!supported.contains(base + 0x20)) break;
    }
    return supported;
  }

  /// Returns the data bytes of a mode 01 reply for [pid], or null if the car
  /// didn't answer.
  Future<List<int>?> requestPid(
    int pid, {
    Duration timeout = defaultTimeout,
  }) async {
    final replies = await _mode01(pid, timeout: timeout);
    return replies.isEmpty ? null : replies.first;
  }

  /// Reads and decodes one value, or returns null if the car didn't answer.
  Future<double?> read(PidDefinition definition) async {
    final data = await requestPid(definition.pid);
    if (data == null || data.length < definition.length) return null;
    return definition.decode(data);
  }

  /// Battery voltage as measured by the adapter itself (`ATRV`). Works even
  /// on cars that don't report voltage as a PID.
  Future<double?> readBatteryVoltage() async {
    final match = _voltage.firstMatch(await send('ATRV'));
    return match == null ? null : double.parse(match.group(1)!);
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    _pending = null;
  }

  Future<List<List<int>>> _mode01(int pid, {required Duration timeout}) async {
    final String response;
    try {
      response = await send('01${_hex(pid)}', timeout: timeout);
    } on ElmException catch (e) {
      if (e.error == ElmError.noData) return [];
      rethrow;
    }
    // Each ECU that answers sends its own line.
    final header = '41${_hex(pid)}';
    final replies = <List<int>>[];
    for (final line in response.split('\n')) {
      final compact = line.replaceAll(' ', '');
      if (!compact.startsWith(header)) continue;
      final data = _parseHex(compact.substring(header.length));
      if (data != null) replies.add(data);
    }
    return replies;
  }

  Future<String> _exchange(String command, Duration timeout) async {
    _buffer.clear();
    final completer = Completer<String>();
    _pending = completer;
    await _transport.write(latin1.encode('$command\r'));
    final String raw;
    try {
      raw = await completer.future.timeout(timeout);
    } on TimeoutException {
      _pending = null;
      throw ElmException(ElmError.timeout, command);
    }
    return _clean(raw, command);
  }

  void _onData(List<int> bytes) {
    _buffer.write(latin1.decode(bytes, allowInvalid: true));
    final text = _buffer.toString();
    final prompt = text.indexOf('>');
    if (prompt == -1) return;
    // Anything after the prompt is unsolicited, so it's dropped.
    _buffer.clear();
    final pending = _pending;
    _pending = null;
    pending?.complete(text.substring(0, prompt));
  }

  static String _clean(String raw, String command) {
    final lines = raw
        // Some clones send null bytes or other noise, especially after ATZ.
        .replaceAll(RegExp(r'[^\x20-\x7E\r\n]'), '')
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where(
          (line) =>
              line.isNotEmpty &&
              line != command &&
              line != 'SEARCHING...' &&
              !_busInitOk.hasMatch(line),
        )
        .toList();
    final response = lines.join('\n');
    for (final line in lines) {
      final error = _errorFor(line);
      if (error != null) throw ElmException(error, command, response);
    }
    return response;
  }

  static ElmError? _errorFor(String line) => switch (line) {
    'NO DATA' => ElmError.noData,
    '?' => ElmError.unknownCommand,
    'UNABLE TO CONNECT' => ElmError.unableToConnect,
    'STOPPED' => ElmError.stopped,
    _ when _busError.hasMatch(line) => ElmError.busError,
    _ => null,
  };

  static String _hex(int byte) =>
      byte.toRadixString(16).padLeft(2, '0').toUpperCase();

  static List<int>? _parseHex(String hex) {
    if (hex.length.isOdd) return null;
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      final byte = int.tryParse(hex.substring(i, i + 2), radix: 16);
      if (byte == null) return null;
      bytes.add(byte);
    }
    return bytes;
  }
}
