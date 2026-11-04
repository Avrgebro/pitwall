import 'dart:async';
import 'dart:convert';

import 'can_id.dart';
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

  /// The connection to the adapter closed.
  disconnected,
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
  /// [log], if given, receives each command and the adapter's raw reply,
  /// which is handy for recording real replies as test data.
  Elm327(this._transport, {this.log}) {
    _subscription = _transport.input.listen(
      _onData,
      onError: (_) => _onClosed(),
      onDone: _onClosed,
    );
  }

  /// Told every exchange: the command, the raw reply, and the error the
  /// reply means, if any.
  final void Function(String command, String rawReply, ElmError? error)? log;

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
  static final _byteCount = RegExp(r'^[0-9A-F]{3}$');
  static final _frameLine = RegExp(r'^[0-9A-F]:');

  final ObdTransport _transport;
  late final StreamSubscription<List<int>> _subscription;
  final _buffer = StringBuffer();
  Completer<String>? _pending;
  String _pendingCommand = '';
  bool _closed = false;
  Future<void> _queue = Future.value();
  CanId _header = CanId.broadcast;
  CanId? _receiveFilter;
  bool _manualFlowControl = false;
  bool _flowControlSupported = true;

  /// Whether the connection to the adapter has closed.
  bool get isClosed => _closed;

  /// Whether the adapter takes the flow-control commands [setTarget] sends,
  /// as [initialize] found.
  bool get setsFlowControl => _flowControlSupported;

  /// Resets the adapter and configures it for compact, header-free replies
  /// with automatic protocol detection, and finds out whether it can set
  /// flow control ([setsFlowControl]). Returns the adapter's banner, such
  /// as `ELM327 v1.5`.
  Future<String> initialize() async {
    final banner = await send('ATZ', timeout: resetTimeout);
    _header = CanId.broadcast;
    _receiveFilter = null;
    _manualFlowControl = false;
    for (final command in ['ATE0', 'ATL0', 'ATS0', 'ATH0', 'ATSP0']) {
      await send(command);
    }
    // Automatic flow control, which it starts in anyway: only whether it
    // knows the command matters.
    try {
      await send('ATFCSM0');
      _flowControlSupported = true;
    } on ElmException catch (e) {
      if (e.error != ElmError.unknownCommand) rethrow;
      _flowControlSupported = false;
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

  /// Asks for the supported standard values (PID 00), which every OBD-II
  /// car answers, only to see whether the car answers at all. Throws
  /// [ElmException] with [ElmError.unableToConnect] if it doesn't, as with
  /// the ignition off.
  Future<void> checkCarAnswers() async {
    await requestPid(0x00);
  }

  /// Battery voltage as measured by the adapter itself (`ATRV`). Works even
  /// on cars that don't report voltage as a PID.
  Future<double?> readBatteryVoltage() async {
    final match = _voltage.firstMatch(await send('ATRV'));
    return match == null ? null : double.parse(match.group(1)!);
  }

  /// Stops listening to the adapter. A command still waiting for its reply
  /// fails at once as disconnected, rather than waiting for its timeout.
  Future<void> dispose() async {
    await _subscription.cancel();
    _onClosed();
  }

  /// Addresses following requests to the module with CAN id [header]
  /// (`ATSH`) and, if [receive] is given, only accepts replies from that id
  /// (`ATCRA`). Pass null to go back to the default broadcast to all
  /// modules. Commands are only sent when something changes.
  Future<void> setTarget(CanId? header, {CanId? receive}) async {
    final target = header ?? CanId.broadcast;
    if (target != _header) {
      await send('ATSH${target.hex}');
      _header = target;
      await _setFlowControl(target);
    }
    if (receive != _receiveFilter) {
      await send(receive == null ? 'ATCRA' : 'ATCRA${receive.hex}');
      _receiveFilter = receive;
    }
  }

  /// Long replies arrive in several CAN frames, and the module waits for a
  /// flow-control frame ("go ahead") after the first one. The adapter only
  /// sends it on its own for the standard 7E0-7E7 range, so for a specific
  /// module it's told explicitly: send to [target], all frames, no pauses.
  /// Back on the broadcast address it returns to automatic.
  ///
  /// Adapters that don't know these commands keep working; only long
  /// replies from modules outside 7E0-7E7 stay cut off.
  Future<void> _setFlowControl(CanId target) async {
    if (!_flowControlSupported) return;
    try {
      if (target == CanId.broadcast) {
        if (_manualFlowControl) await send('ATFCSM0');
        _manualFlowControl = false;
      } else {
        await send('ATFCSH${target.hex}');
        if (!_manualFlowControl) {
          await send('ATFCSD300000');
          await send('ATFCSM1');
        }
        _manualFlowControl = true;
      }
    } on ElmException catch (e) {
      if (e.error != ElmError.unknownCommand) rethrow;
      _flowControlSupported = false;
    }
  }

  /// Sends a request for [service] with identifier bytes [id] (a PID or a
  /// data identifier) and returns the reply data after the echoed service
  /// and identifier, one list per module that answered.
  ///
  /// Empty if no module answered or the module refused the request.
  Future<List<List<int>>> request(
    int service,
    List<int> id, {
    Duration timeout = defaultTimeout,
  }) async {
    final idHex = id.map(_hex).join();
    final String response;
    try {
      response = await send('${_hex(service)}$idHex', timeout: timeout);
    } on ElmException catch (e) {
      if (e.error == ElmError.noData) return [];
      rethrow;
    }
    // A positive reply echoes the service + 0x40 and the identifier. Refusals
    // (`7F <service> <reason>`) don't match and are left out.
    final prefix = '${_hex(service + 0x40)}$idHex';
    final replies = <List<int>>[];
    for (final message in _messages(response)) {
      if (!message.startsWith(prefix)) continue;
      final data = _parseHex(message.substring(prefix.length));
      if (data != null) replies.add(data);
    }
    return replies;
  }

  Future<List<List<int>>> _mode01(int pid, {required Duration timeout}) =>
      request(0x01, [pid], timeout: timeout);

  Future<String> _exchange(String command, Duration timeout) async {
    if (_closed) throw ElmException(ElmError.disconnected, command);
    _buffer.clear();
    final completer = Completer<String>();
    _pending = completer;
    _pendingCommand = command;
    try {
      await _transport.write(latin1.encode('$command\r'));
    } on TransportClosed {
      // This exchange fails here, not through its reply.
      _pending = null;
      _onClosed();
      log?.call(command, '(disconnected)', ElmError.disconnected);
      throw ElmException(ElmError.disconnected, command);
    }
    final String raw;
    try {
      raw = await completer.future.timeout(timeout);
    } on TimeoutException {
      _pending = null;
      log?.call(command, '(timeout)', ElmError.timeout);
      throw ElmException(ElmError.timeout, command);
    }
    try {
      final response = _clean(raw, command);
      log?.call(command, raw, null);
      return response;
    } on ElmException catch (e) {
      log?.call(command, raw, e.error);
      rethrow;
    }
  }

  void _onClosed() {
    _closed = true;
    final pending = _pending;
    _pending = null;
    if (pending == null) return;
    log?.call(_pendingCommand, '(disconnected)', ElmError.disconnected);
    pending.completeError(ElmException(ElmError.disconnected, _pendingCommand));
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

  /// Splits a cleaned reply into messages, without spaces. Single-frame
  /// replies are one line each, one per module. A multi-frame reply (CAN,
  /// headers off) is a byte-count line like `00F` followed by numbered lines
  /// like `0:62B002...`, which are joined into one message.
  static List<String> _messages(String response) {
    final messages = <String>[];
    final frames = StringBuffer();
    int? length;

    void finishMultiFrame() {
      if (frames.isEmpty) return;
      final data = frames.toString();
      final count = length;
      if (count == null) {
        messages.add(data);
      } else if (data.length >= count * 2) {
        // The last frame is padded; cut it to the announced byte count.
        messages.add(data.substring(0, count * 2));
      }
      // Fewer bytes than announced means frames went missing. A partial
      // reply would decode to wrong values, so it's dropped.
      frames.clear();
      length = null;
    }

    for (final line in response.split('\n')) {
      final compact = line.replaceAll(' ', '');
      if (_byteCount.hasMatch(compact)) {
        finishMultiFrame();
        length = int.parse(compact, radix: 16);
      } else if (_frameLine.hasMatch(compact)) {
        frames.write(compact.substring(2));
      } else {
        finishMultiFrame();
        messages.add(compact);
      }
    }
    finishMultiFrame();
    return messages;
  }

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
