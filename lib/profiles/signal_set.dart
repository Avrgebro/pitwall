import 'dart:convert';

/// A vehicle profile in OBDb's signal-set format (v3), as found in
/// `signalsets/v3/default.json` in each https://github.com/OBDb repository.
///
/// Profiles are imported by the user, so parsing treats them as untrusted:
/// only read services are accepted, and anything Pitwall can't send safely
/// or doesn't support yet ends up in [skipped] instead of [commands].
class SignalSet {
  SignalSet._(this.commands, this.skipped);

  /// Services that only read data: current data, vehicle info, and the two
  /// manufacturer "read data by identifier" services.
  static const readServices = {0x01, 0x09, 0x21, 0x22};

  static final _canId = RegExp(r'^[0-9A-F]{3}$');
  static final _hexBytes = RegExp(r'^(?:[0-9A-F]{2}){1,4}$');

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
      final description = _describe(entry);
      try {
        commands.add(_parseCommand(entry));
      } on _Unsupported catch (e) {
        skipped.add(SkippedCommand(description, e.reason));
      }
    }
    return SignalSet._(commands, skipped);
  }

  int get signalCount =>
      commands.fold(0, (count, command) => count + command.signals.length);

  /// Commands that apply to a car of [modelYear].
  Iterable<ProfileCommand> commandsFor(int modelYear) =>
      commands.where((command) => command.filter?.matches(modelYear) ?? true);

  static ProfileCommand _parseCommand(Map entry) {
    final cmd = entry['cmd'];
    if (cmd is! Map || cmd.length != 1) {
      throw const _Unsupported('missing or unusual request');
    }
    final serviceHex = cmd.keys.single.toString().toUpperCase();
    final idHex = cmd.values.single.toString().toUpperCase();
    final service = int.tryParse(serviceHex, radix: 16);
    if (service == null || !readServices.contains(service)) {
      throw _Unsupported('service $serviceHex is not a read service');
    }
    if (!_hexBytes.hasMatch(idHex)) {
      throw _Unsupported('unusual identifier $idHex');
    }
    final header = entry['hdr']?.toString().toUpperCase();
    final receive = entry['rax']?.toString().toUpperCase();
    if (header == null || !_canId.hasMatch(header)) {
      throw const _Unsupported('29-bit or unusual module address');
    }
    if (receive != null && !_canId.hasMatch(receive)) {
      throw const _Unsupported('29-bit or unusual reply address');
    }
    if (entry['eax'] != null) {
      throw const _Unsupported('needs extended addressing');
    }
    if (entry['fcm1'] == true) {
      throw const _Unsupported('needs special flow control');
    }
    final signals = [
      for (final signal in entry['signals'] as List? ?? const [])
        if (signal is Map) ?ProfileSignal._parse(signal),
    ];
    if (signals.isEmpty) throw const _Unsupported('no usable signals');
    return ProfileCommand(
      header: header,
      receive: receive,
      service: service,
      id: [
        for (var i = 0; i < idHex.length; i += 2)
          int.parse(idHex.substring(i, i + 2), radix: 16),
      ],
      filter: YearFilter._parse(entry['filter']),
      signals: signals,
    );
  }

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

class SkippedCommand {
  const SkippedCommand(this.description, this.reason);

  final String description;
  final String reason;
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
      from: (json['from'] as num?)?.toInt(),
      to: (json['to'] as num?)?.toInt(),
      years: {
        for (final year in json['years'] as List? ?? const [])
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
    this.factor = 1,
  });

  /// OBDb's signal id, e.g. `TUCSON_FLI_VOL`.
  final String id;
  final String name;

  /// Field name in the webhook payload.
  final String key;
  final String unit;
  final SignalFormat format;

  /// Unit conversion applied after decoding, e.g. miles to km.
  final double factor;

  /// Decodes this signal from a reply's data, or returns null if the reply
  /// is too short or the value means "not available".
  double? decode(List<int> data) {
    final value = format.decode(data);
    return value == null ? null : value * factor;
  }

  static const _milesToKm = 1.609344;

  static ProfileSignal? _parse(Map json) {
    final id = json['id'];
    final format = SignalFormat._parse(json['fmt']);
    if (id is! String || format == null) return null;
    final metric = json['suggestedMetric'];
    final (key, unit, factor) = switch ((metric, format.unit)) {
      ('fuelTankLevel', 'percent') => ('fuel_level_pct', '%', 1.0),
      ('fuelTankLevel', 'liters') => ('fuel_level_l', 'L', 1.0),
      ('odometer', 'kilometers') => ('odometer_km', 'km', 1.0),
      ('odometer', 'miles') => ('odometer_km', 'km', _milesToKm),
      _ => (id.toLowerCase(), format.unit, 1.0),
    };
    return ProfileSignal(
      id: id,
      name: json['name'] as String? ?? id,
      key: key,
      unit: unit,
      format: format,
      factor: factor,
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
    final bitIndex = json['bix'] as num?;
    final bitLength = json['len'] as num?;
    if (bitLength == null) return null;
    final divide = json['div'] as num? ?? 1;
    if (divide == 0) return null;
    return SignalFormat(
      bitIndex: bitIndex?.toInt() ?? 0,
      bitLength: bitLength.toInt(),
      littleEndian: json['blsb'] == true,
      signed: json['sign'] == true,
      multiply: json['mul'] as num? ?? 1,
      divide: divide,
      add: json['add'] as num? ?? 0,
      nullMin: json['nullmin'] as num?,
      nullMax: json['nullmax'] as num?,
      min: json['min'] as num?,
      max: json['max'] as num?,
      unit: json['unit'] as String? ?? '',
    );
  }
}

class _Unsupported implements Exception {
  const _Unsupported(this.reason);

  final String reason;
}
