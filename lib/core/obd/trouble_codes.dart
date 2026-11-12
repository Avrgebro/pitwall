import 'package:flutter/foundation.dart';

import 'elm327.dart';

/// The trouble codes the car reports, as standard OBD-II codes such as
/// `P0133`: what's behind the check-engine light, what's pending, and what
/// stays until a repair is proven. Pitwall only reads them; it never
/// clears them, which would change the car.
@immutable
class TroubleCodes {
  const TroubleCodes({
    required this.checkEngine,
    this.stored = const [],
    this.pending = const [],
    this.permanent = const [],
  });

  /// Whether the check-engine light (MIL) is on.
  final bool checkEngine;

  /// Confirmed faults (mode 03): the ones behind the light.
  final List<String> stored;

  /// Faults seen once and not yet confirmed (mode 07): the early warning.
  final List<String> pending;

  /// Faults that only clear once the car has proven the repair (mode 0A).
  final List<String> permanent;

  bool get isEmpty =>
      !checkEngine && stored.isEmpty && pending.isEmpty && permanent.isEmpty;

  /// In words, as "Trouble codes: check-engine light on, stored P0133".
  String get summary {
    if (isEmpty) return 'No trouble codes';
    final parts = [
      if (checkEngine) 'check-engine light on',
      if (stored.isNotEmpty) 'stored ${stored.join(' ')}',
      if (pending.isNotEmpty) 'pending ${pending.join(' ')}',
      if (permanent.isNotEmpty) 'permanent ${permanent.join(' ')}',
    ];
    return 'Trouble codes: ${parts.join(', ')}';
  }

  /// The same codes, with the light as it is now.
  TroubleCodes withLight(bool checkEngine) => TroubleCodes(
    checkEngine: checkEngine,
    stored: stored,
    pending: pending,
    permanent: permanent,
  );

  Map<String, Object?> toJson() => {
    'check_engine': checkEngine,
    'stored': stored,
    'pending': pending,
    'permanent': permanent,
  };

  /// What [toJson] wrote; codes that aren't text are left out.
  factory TroubleCodes.fromJson(Map<String, Object?> json) {
    List<String> codes(Object? list) => [
      if (list is List)
        for (final code in list)
          if (code is String) code,
    ];
    return TroubleCodes(
      checkEngine: json['check_engine'] == true,
      stored: codes(json['stored']),
      pending: codes(json['pending']),
      permanent: codes(json['permanent']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TroubleCodes &&
      other.checkEngine == checkEngine &&
      listEquals(other.stored, stored) &&
      listEquals(other.pending, pending) &&
      listEquals(other.permanent, permanent);

  @override
  int get hashCode => Object.hash(
    checkEngine,
    Object.hashAll(stored),
    Object.hashAll(pending),
    Object.hashAll(permanent),
  );
}

/// Trouble codes and when they were read: kept on through readings that
/// don't read them again, so they're never passed off as read since.
typedef TroubleCodesRead = ({TroubleCodes codes, DateTime at});

/// The check-engine light and how many confirmed codes there are, from
/// every module's reply to `0101`: the light is on if any module turned it
/// on, and the count is all of theirs.
({bool checkEngine, int count}) lightFrom(List<List<int>> replies) {
  var checkEngine = false;
  var count = 0;
  for (final data in replies) {
    if (data.isEmpty) continue;
    checkEngine = checkEngine || data[0] & 0x80 != 0;
    count += data[0] & 0x7F;
  }
  return (checkEngine: checkEngine, count: count);
}

/// The codes in every module's reply to `03`, `07` or `0A`, each once, in
/// the order they came.
///
/// On CAN, a reply starts with how many codes follow, so it has an odd
/// length; older protocols send codes alone, padded with `0000`, which
/// means none.
List<String> codesFrom(List<List<int>> replies) {
  final codes = <String>{};
  for (final data in replies) {
    final start = data.length.isOdd ? 1 : 0;
    for (var i = start; i + 1 < data.length; i += 2) {
      if (data[i] == 0 && data[i + 1] == 0) continue;
      codes.add(troubleCode(data[i], data[i + 1]));
    }
  }
  return codes.toList();
}

/// One code as written, from its two bytes: the first two bits give the
/// system (P powertrain, C chassis, B body, U network), the rest is four
/// hex digits, as in `P0133`.
String troubleCode(int high, int low) {
  const systems = ['P', 'C', 'B', 'U'];
  final system = systems[high >> 6];
  final first = (high >> 4) & 0x3;
  final rest = ((high & 0x0F) << 8 | low)
      .toRadixString(16)
      .toUpperCase()
      .padLeft(3, '0');
  return '$system$first$rest';
}

/// Reads the check-engine light and the count of confirmed codes, which
/// shows when the codes themselves changed. One short request.
Future<({bool checkEngine, int count})> readLight(Elm327 elm) async =>
    lightFrom(await elm.request(0x01, [0x01]));

/// Reads every kind of trouble code. A kind the car doesn't support, as
/// older cars with permanent codes, reads as none. [light], when just read,
/// isn't asked for again.
Future<TroubleCodes> readTroubleCodes(
  Elm327 elm, {
  ({bool checkEngine, int count})? light,
}) async {
  light ??= await readLight(elm);
  return TroubleCodes(
    checkEngine: light.checkEngine,
    stored: codesFrom(await elm.request(0x03, const [])),
    pending: codesFrom(await elm.request(0x07, const [])),
    permanent: codesFrom(await elm.request(0x0A, const [])),
  );
}

/// One connection's trouble codes: the light and the count of confirmed
/// codes come with every reading, one short request; all the codes are
/// read on the first, when the count changes, and every [rereadAfter], as
/// new pending codes don't change the count.
class TroubleCodesReader {
  TroubleCodesReader();

  static const rereadAfter = Duration(minutes: 10);

  ({TroubleCodes codes, int count, DateTime at})? _full;

  /// The codes last read in full, and when, if any were.
  TroubleCodesRead? get known => switch (_full) {
    (:final codes, :final at, count: _) => (codes: codes, at: at),
    null => null,
  };

  /// Reads the light, and all the codes if they're due, at [now]. Returns
  /// them, as read when they were, and whether they differ from the codes
  /// known before. Throws what [elm] throws; the codes known stay.
  Future<({TroubleCodesRead read, bool changed})> read(
    Elm327 elm,
    DateTime now,
  ) async {
    final light = await readLight(elm);
    if (_full case final full?
        when full.count == light.count &&
            now.difference(full.at) < rereadAfter) {
      // The light is new; the codes are as read then.
      return (
        read: (codes: full.codes.withLight(light.checkEngine), at: full.at),
        changed: false,
      );
    }
    final codes = await readTroubleCodes(elm, light: light);
    final changed = _full?.codes != codes;
    _full = (codes: codes, count: light.count, at: now);
    return (read: (codes: codes, at: now), changed: changed);
  }
}
