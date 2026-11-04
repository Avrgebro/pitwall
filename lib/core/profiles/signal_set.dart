import 'dart:convert';

import '../obd/can_id.dart';

/// A vehicle profile in OBDb's signal-set format (v3), as found in
/// `signalsets/v3/default.json` in each https://github.com/OBDb repository.
///
/// Profiles are imported by the user, so parsing treats them as untrusted:
/// only read services are accepted, and anything Pitwall can't send safely
/// or doesn't support yet is a [SkippedRequest] rather than a
/// [ProfileCommand]. Every
/// field is read by checking its type, so a field that isn't what OBDb
/// writes counts as missing rather than failing the whole profile.
class SignalSet {
  SignalSet._(this.source, this.requests);

  /// Services that only read data: current data, vehicle info, and the two
  /// manufacturer "read data by identifier" services.
  static const readServices = {0x01, 0x09, 0x21, 0x22};

  static final _hexBytes = RegExp(r'^(?:[0-9A-F]{2}){1,4}$');

  /// The file this was parsed from, kept so it can be saved as imported.
  final String source;

  /// Every request in the profile, in its order: ones Pitwall sends, and
  /// ones it skips, with why.
  final List<ProfileRequest> requests;

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
    final requests = <ProfileRequest>[];
    for (final entry in json['commands'] as List) {
      if (entry is! Map) continue;
      // Kept for skipped requests too, to say what they would have read. A
      // filter that doesn't parse is no filter: the request applies to
      // every year. That's safe, as only read services are ever sent.
      final filter = YearFilter._parse(entry['filter']);
      final signals = [
        for (final signal in _list(entry['signals']))
          if (signal is Map) ?ProfileSignal._parse(signal),
      ];
      try {
        requests.add(_parseCommand(entry, filter, signals));
      } on _Unsupported catch (e) {
        requests.add(
          SkippedRequest(
            _describe(entry),
            e.reason,
            filter: filter,
            signals: signals,
          ),
        );
      }
    }
    return SignalSet._(source, requests);
  }

  /// The requests that apply to a car of [modelYear].
  Iterable<ProfileRequest> requestsFor(int modelYear) =>
      requests.where((request) => request.appliesTo(modelYear));

  /// The requests Pitwall sends to a car of [modelYear].
  Iterable<ProfileCommand> commandsFor(int modelYear) =>
      requestsFor(modelYear).whereType<ProfileCommand>();

  /// The requests Pitwall sends to a car of [modelYear], each with the
  /// values read through it. A value several requests carry is read
  /// through the first, so its name, unit and reading all come from one
  /// place.
  List<({ProfileCommand command, List<ProfileSignal> signals})> readsFor(
    int modelYear,
  ) {
    final claimed = <String>{};
    return [
      for (final command in commandsFor(modelYear))
        (
          command: command,
          signals: [
            for (final signal in command.signals)
              if (claimed.add(signal.key)) signal,
          ],
        ),
    ];
  }

  /// What this profile offers a car of [modelYear]; see [ProfileSummary].
  ProfileSummary summaryFor(int modelYear) {
    final readable = {
      for (final (:signals, command: _) in readsFor(modelYear))
        for (final signal in signals) signal.key: signal,
    };
    final missing = <SkipReason, Map<String, ProfileSignal>>{};
    var neverSent = 0;
    for (final request in requestsFor(modelYear)) {
      switch (request) {
        case ProfileCommand():
          break;
        case SkippedRequest(reason: SkipReason.notReadOnly):
          neverSent++;
        case SkippedRequest(:final reason, :final signals):
          final byKey = missing[reason] ??= {};
          for (final signal in signals) {
            // Read through another request, so not missing after all.
            if (!readable.containsKey(signal.key)) byKey[signal.key] = signal;
          }
      }
    }
    return ProfileSummary(
      year: modelYear,
      readable: readable.values.toList(),
      notYetReadable: [
        for (final MapEntry(key: reason, value: byKey) in missing.entries)
          if (byKey.isNotEmpty)
            (reason: reason, signals: byKey.values.toList()),
      ],
      neverSentRequests: neverSent,
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
    // Anything but an 11-bit id, such as a 29-bit one, is an address
    // Pitwall can't send to yet.
    final header = CanId.tryParse('${entry['hdr']}');
    if (header == null) throw const _Unsupported(SkipReason.extendedAddress);
    final rax = entry['rax'];
    final receive = rax == null ? null : CanId.tryParse('$rax');
    if (rax != null && receive == null) {
      throw const _Unsupported(SkipReason.extendedAddress);
    }
    if (entry['eax'] != null) {
      throw const _Unsupported(SkipReason.extendedAddress);
    }
    if (signals.isEmpty) throw const _Unsupported(SkipReason.noUsableSignals);
    return ProfileCommand(
      header: header,
      receive: receive,
      needsFlowControl: entry['fcm1'] == true,
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

/// One request in a profile: the model years it's for, and the values its
/// reply holds. Pitwall either sends it, as a [ProfileCommand], or skips
/// it, as a [SkippedRequest].
sealed class ProfileRequest {
  const ProfileRequest({required this.filter, required this.signals});

  final YearFilter? filter;
  final List<ProfileSignal> signals;

  bool appliesTo(int modelYear) => filter?.matches(modelYear) ?? true;
}

/// A request Pitwall sends to one module.
final class ProfileCommand extends ProfileRequest {
  const ProfileCommand({
    required this.header,
    required this.receive,
    this.needsFlowControl = false,
    required this.service,
    required this.id,
    required super.filter,
    required super.signals,
  });

  /// CAN id the request is sent to, e.g. `7C6`.
  final CanId header;

  /// CAN id the reply comes from, e.g. `7CE`, if the profile names one.
  final CanId? receive;

  /// OBDb's `fcm1`: the reply comes back whole only with flow control
  /// aimed at the module, which `Elm327.setTarget` sets up where the
  /// adapter can.
  final bool needsFlowControl;

  final int service;
  final List<int> id;
}

/// Why a request in a profile isn't used.
enum SkipReason {
  /// Not a read-only service. Pitwall never sends these.
  notReadOnly,

  /// A request Pitwall doesn't understand.
  unusualRequest,

  /// 29-bit or extended CAN addressing, not supported yet.
  extendedAddress,

  /// None of its signals could be read.
  noUsableSignals,
}

/// A request Pitwall doesn't send, and why. Its signals are what it would
/// have read.
final class SkippedRequest extends ProfileRequest {
  const SkippedRequest(
    this.description,
    this.reason, {
    required super.filter,
    required super.signals,
  });

  /// The request, like `7E0: 22 0100`.
  final String description;
  final SkipReason reason;
}

/// What a profile offers a car of one model year; see
/// [SignalSet.summaryFor].
class ProfileSummary {
  ProfileSummary({
    required this.year,
    required this.readable,
    required this.notYetReadable,
    required this.neverSentRequests,
  }) : readableByCategory = byCategory(readable);

  /// The model year it's for.
  final int year;

  /// Each value the profile can read, once.
  final List<ProfileSignal> readable;

  /// [readable] by category, the largest first.
  final List<SignalGroup> readableByCategory;

  /// Values Pitwall can't read yet, by reason: only ones no sent request
  /// reads. Requests that would change something in the car aren't among
  /// them; see [neverSentRequests].
  final List<({SkipReason reason, List<ProfileSignal> signals})> notYetReadable;

  /// Requests that would change something in the car, which are never
  /// sent.
  final int neverSentRequests;

  /// [signals] by category, the largest first.
  static List<SignalGroup> byCategory(Iterable<ProfileSignal> signals) {
    final groups = <String, List<ProfileSignal>>{};
    for (final signal in signals) {
      (groups[signal.category] ??= []).add(signal);
    }
    return [
      for (final MapEntry(:key, :value) in groups.entries)
        SignalGroup(key, value),
    ]..sort((a, b) => b.signals.length - a.signals.length);
  }
}

/// The values in one OBDb category, such as `Engine`.
class SignalGroup {
  const SignalGroup(this.category, this.signals);

  final String category;
  final List<ProfileSignal> signals;
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
