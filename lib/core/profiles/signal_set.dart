import 'dart:convert';

/// A vehicle profile in OBDb's signal-set format (v3), as found in
/// `signalsets/v3/default.json` in each https://github.com/OBDb repository.
///
/// Profiles are imported by the user, so parsing treats them as untrusted:
/// only read services are accepted, and anything Pitwall can't send safely
/// or doesn't support yet ends up in [skipped] instead of [commands]. Every
/// field is read by checking its type, so a field that isn't what OBDb
/// writes counts as missing rather than failing the whole profile.
class SignalSet {
  SignalSet._(this.source, this.commands, this.skipped);

  /// Services that only read data: current data, vehicle info, and the two
  /// manufacturer "read data by identifier" services.
  static const readServices = {0x01, 0x09, 0x21, 0x22};

  static final _canId = RegExp(r'^[0-9A-F]{3}$');
  static final _hexBytes = RegExp(r'^(?:[0-9A-F]{2}){1,4}$');

  /// The file this was parsed from, kept so it can be saved as imported.
  final String source;

  final List<ProfileCommand> commands;
  final List<SkippedCommand> skipped;

  /// Parses a signal-set file. Throws [FormatException] if it isn't one.
  factory SignalSet.parse(String source) {
    final Object? json;
    try {
      json = jsonDecode(source);
    } on FormatException {
      throw const FormatException('Not a JSON file.');
    }
    if (json is! Map || json['commands'] is! List) {
      throw const FormatException('Not an OBDb signal set: no "commands".');
    }
    final commands = <ProfileCommand>[];
    final skipped = <SkippedCommand>[];
    for (final entry in json['commands'] as List) {
      if (entry is! Map) continue;
      // Kept for skipped requests too, to say what they would have read.
      final filter = YearFilter._parse(entry['filter']);
      final signals = [
        for (final signal in _list(entry['signals']))
          if (signal is Map) ?ProfileSignal._parse(signal),
      ];
      try {
        commands.add(_parseCommand(entry, filter, signals));
      } on _Unsupported catch (e) {
        skipped.add(
          SkippedCommand(
            _describe(entry),
            e.reason,
            filter: filter,
            signals: signals,
          ),
        );
      }
    }
    return SignalSet._(source, commands, skipped);
  }

  int get signalCount =>
      commands.fold(0, (count, command) => count + command.signals.length);

  /// Commands that apply to a car of [modelYear].
  Iterable<ProfileCommand> commandsFor(int modelYear) =>
      commands.where((command) => command.filter?.matches(modelYear) ?? true);

  /// Skipped requests that would apply to a car of [modelYear].
  Iterable<SkippedCommand> skippedFor(int modelYear) =>
      skipped.where((command) => command.filter?.matches(modelYear) ?? true);

  /// What this profile offers a car of [modelYear]: the values it can read,
  /// by category, and the ones it can't, by reason.
  ProfileSummary summaryFor(int modelYear) {
    final readable = <String, ProfileSignal>{
      for (final command in commandsFor(modelYear))
        for (final signal in command.signals) signal.key: signal,
    };
    final unreadable = <SkipReason, Map<String, ProfileSignal>>{};
    final requests = <SkipReason, int>{};
    for (final command in skippedFor(modelYear)) {
      requests[command.reason] = (requests[command.reason] ?? 0) + 1;
      final signals = unreadable[command.reason] ??= {};
      for (final signal in command.signals) {
        // Read through another request, so not missing after all.
        if (!readable.containsKey(signal.key)) signals[signal.key] = signal;
      }
    }
    return ProfileSummary(
      readable: readable.values.toList(),
      unreadable: {
        for (final MapEntry(key: reason, value: count) in requests.entries)
          reason: (
            requests: count,
            signals: unreadable[reason]!.values.toList(),
          ),
      },
    );
  }

  static ProfileCommand _parseCommand(
    Map entry,
    YearFilter? filter,
    List<ProfileSignal> signals,
  ) {
    final cmd = entry['cmd'];
    if (cmd is! Map || cmd.length != 1) {
      throw const _Unsupported(SkipReason.unusualRequest);
    }
    final serviceHex = cmd.keys.single.toString().toUpperCase();
    final idHex = cmd.values.single.toString().toUpperCase();
    final service = int.tryParse(serviceHex, radix: 16);
    if (service == null || !readServices.contains(service)) {
      throw const _Unsupported(SkipReason.notReadOnly);
    }
    if (!_hexBytes.hasMatch(idHex)) {
      throw const _Unsupported(SkipReason.unusualRequest);
    }
    final header = entry['hdr']?.toString().toUpperCase();
    final receive = entry['rax']?.toString().toUpperCase();
    if (header == null || !_canId.hasMatch(header)) {
      throw const _Unsupported(SkipReason.extendedAddress);
    }
    if (receive != null && !_canId.hasMatch(receive)) {
      throw const _Unsupported(SkipReason.extendedAddress);
    }
    if (entry['eax'] != null) {
      throw const _Unsupported(SkipReason.extendedAddress);
    }
    if (entry['fcm1'] == true) {
      throw const _Unsupported(SkipReason.specialFlowControl);
    }
    if (signals.isEmpty) throw const _Unsupported(SkipReason.noUsableSignals);
    return ProfileCommand(
      header: header,
      receive: receive,
      service: service,
      id: [
        for (var i = 0; i < idHex.length; i += 2)
          int.parse(idHex.substring(i, i + 2), radix: 16),
      ],
      filter: filter,
      signals: signals,
    );
  }

  static List<Object?> _list(Object? json) => json is List ? json : const [];

  static String _describe(Map entry) {
    final cmd = entry['cmd'];
    final request = cmd is Map
        ? cmd.entries.map((e) => '${e.key} ${e.value}').join(' ')
        : '?';
    return '${entry['hdr'] ?? '?'}: $request';
  }
}

/// One request to one module, and the signals decoded from its reply.
class ProfileCommand {
  const ProfileCommand({
    required this.header,
    required this.receive,
    required this.service,
    required this.id,
    required this.filter,
    required this.signals,
  });

  /// CAN id the request is sent to, e.g. `7C6`.
  final String header;

  /// CAN id the reply comes from, e.g. `7CE`, if the profile names one.
  final String? receive;

  final int service;
  final List<int> id;
  final YearFilter? filter;
  final List<ProfileSignal> signals;
}

/// Why a request in a profile isn't used.
enum SkipReason {
  /// Not a read-only service. Pitwall never sends these.
  notReadOnly,

  /// A request Pitwall doesn't understand.
  unusualRequest,

  /// 29-bit or extended CAN addressing, not supported yet.
  extendedAddress,

  /// Needs flow-control settings Pitwall doesn't support yet.
  specialFlowControl,

  /// None of its signals could be read.
  noUsableSignals,
}

class SkippedCommand {
  const SkippedCommand(
    this.description,
    this.reason, {
    this.filter,
    this.signals = const [],
  });

  /// The request, like `7E0: 22 0100`.
  final String description;
  final SkipReason reason;
  final YearFilter? filter;

  /// What it would have read.
  final List<ProfileSignal> signals;
}

/// What a profile offers a car of one model year; see
/// [SignalSet.summaryFor].
class ProfileSummary {
  const ProfileSummary({required this.readable, required this.unreadable});

  /// Each value the profile can read, once.
  final List<ProfileSignal> readable;

  /// Requests that can't be sent, by reason, and the values only they hold.
  final Map<SkipReason, ({int requests, List<ProfileSignal> signals})>
  unreadable;

  /// How many values each category has, the largest first.
  static List<({String category, int count})> byCategory(
    Iterable<ProfileSignal> signals,
  ) {
    final counts = <String, int>{};
    for (final signal in signals) {
      counts[signal.category] = (counts[signal.category] ?? 0) + 1;
    }
    return [
      for (final MapEntry(:key, :value)
          in counts.entries.toList()..sort((a, b) => b.value - a.value))
        (category: key, count: value),
    ];
  }
}

/// Model years a command applies to. OBDb filters are a union: `to` covers
/// that year and earlier, `from` that year and later, `years` exact years.
class YearFilter {
  const YearFilter({this.from, this.to, this.years = const {}});

  final int? from;
  final int? to;
  final Set<int> years;

  bool matches(int year) =>
      (to != null && year <= to!) ||
      (from != null && year >= from!) ||
      years.contains(year);

  static YearFilter? _parse(Object? json) {
    if (json is! Map) return null;
    return YearFilter(
      from: _int(json['from']),
      to: _int(json['to']),
      years: {
        for (final year in SignalSet._list(json['years']))
          if (year is num) year.toInt(),
      },
    );
  }
}

class ProfileSignal {
  const ProfileSignal({
    required this.id,
    required this.name,
    required this.key,
    required this.unit,
    required this.format,
    this.path,
  });

  /// OBDb's signal id, e.g. `TUCSON_FLI_VOL`.
  final String id;
  final String name;

  /// Where OBDb files the signal, e.g. `Engine.Misfires`.
  final String? path;

  /// The top level of [path], such as `Engine`, or `Other` without one.
  String get category => switch (path?.split('.').first) {
    final top? when top.isNotEmpty => top,
    _ => 'Other',
  };

  /// Field name in the webhook payload: the OBDb id in lowercase, e.g.
  /// `tucson_fli_vol`. Pitwall doesn't rename signals or convert their
  /// units; the profile is the source of truth.
  final String key;

  /// OBDb's unit name, e.g. `liters`.
  final String unit;
  final SignalFormat format;

  /// Decodes this signal from a reply's data, or returns null if the reply
  /// is too short or the value means "not available".
  double? decode(List<int> data) => format.decode(data);

  static ProfileSignal? _parse(Map json) {
    final id = json['id'];
    final format = SignalFormat._parse(json['fmt']);
    if (id is! String || format == null) return null;
    return ProfileSignal(
      id: id,
      name: switch (json['name']) {
        final String name => name,
        _ => id,
      },
      key: id.toLowerCase(),
      unit: format.unit,
      format: format,
      path: switch (json['path']) {
        final String path => path,
        _ => null,
      },
    );
  }
}

/// Where a value sits in a reply and how to scale it.
///
/// Bits are numbered from the most significant bit of the first data byte
/// after the echoed service and identifier.
class SignalFormat {
  const SignalFormat({
    required this.bitIndex,
    required this.bitLength,
    this.littleEndian = false,
    this.signed = false,
    this.multiply = 1,
    this.divide = 1,
    this.add = 0,
    this.nullMin,
    this.nullMax,
    this.min,
    this.max,
    this.unit = '',
  });

  final int bitIndex;
  final int bitLength;

  /// Bytes in little-endian order (OBDb's `blsb`). Only for whole bytes.
  final bool littleEndian;
  final bool signed;
  final num multiply;
  final num divide;
  final num add;

  /// Values at or below [nullMin], or at or above [nullMax], mean
  /// "not available".
  final num? nullMin;
  final num? nullMax;

  /// The signal's valid range. Values outside it are treated as "not
  /// available", e.g. a module filling an unsupported field with FF bytes.
  final num? min;
  final num? max;
  final String unit;

  double? decode(List<int> data) {
    if (bitLength < 1 || bitLength > 48) return null;
    if (bitIndex < 0 || bitIndex + bitLength > data.length * 8) return null;
    var raw = 0;
    if (littleEndian) {
      if (bitIndex % 8 != 0 || bitLength % 8 != 0) return null;
      final first = bitIndex ~/ 8;
      for (var i = bitLength ~/ 8 - 1; i >= 0; i--) {
        raw = (raw << 8) | data[first + i];
      }
    } else {
      for (var bit = bitIndex; bit < bitIndex + bitLength; bit++) {
        raw = (raw << 1) | ((data[bit >> 3] >> (7 - (bit & 7))) & 1);
      }
    }
    if (signed && raw & (1 << (bitLength - 1)) != 0) raw -= 1 << bitLength;
    final value = raw * multiply / divide + add;
    if (nullMin case final min? when value <= min) return null;
    if (nullMax case final max? when value >= max) return null;
    if (min case final min? when value < min) return null;
    if (max case final max? when value > max) return null;
    return value;
  }

  static SignalFormat? _parse(Object? json) {
    if (json is! Map) return null;
    final bitLength = _int(json['len']);
    if (bitLength == null) return null;
    final divide = _num(json['div']) ?? 1;
    if (divide == 0) return null;
    return SignalFormat(
      bitIndex: _int(json['bix']) ?? 0,
      bitLength: bitLength,
      littleEndian: json['blsb'] == true,
      signed: json['sign'] == true,
      multiply: _num(json['mul']) ?? 1,
      divide: divide,
      add: _num(json['add']) ?? 0,
      nullMin: _num(json['nullmin']),
      nullMax: _num(json['nullmax']),
      min: _num(json['min']),
      max: _num(json['max']),
      unit: switch (json['unit']) {
        final String unit => unit,
        _ => '',
      },
    );
  }
}

num? _num(Object? json) => json is num ? json : null;

int? _int(Object? json) => json is num ? json.toInt() : null;

class _Unsupported implements Exception {
  const _Unsupported(this.reason);

  final SkipReason reason;
}
