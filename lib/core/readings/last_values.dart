import 'package:flutter/foundation.dart';

import '../storage/app_files.dart';
import 'unreported.dart';

/// A value as last read from the car, and when.
@immutable
class LastValue {
  const LastValue(this.value, this.readAt, {required this.seq});

  final num value;
  final DateTime readAt;

  /// The sequence number of the reading it went out in, to tell whether
  /// it's delivered.
  final int seq;

  @override
  bool operator ==(Object other) =>
      other is LastValue &&
      other.value == value &&
      other.readAt == readAt &&
      other.seq == seq;

  @override
  int get hashCode => Object.hash(value, readAt, seq);
}

/// A value asked for that didn't come back in the latest reading that
/// asked for it, and why.
@immutable
class UnreportedValue {
  const UnreportedValue(this.reason, this.at);

  final Unreported reason;
  final DateTime at;

  @override
  bool operator ==(Object other) =>
      other is UnreportedValue && other.reason == reason && other.at == at;

  @override
  int get hashCode => Object.hash(reason, at);
}

/// The last value of each key every vehicle reported, by vehicle id, and
/// the values asked for that didn't come back.
///
/// A reading replaces only the keys it carries, so a value the car stops
/// reporting, say as it switches off, keeps the time it was last read.
@immutable
class LastValues {
  const LastValues([this.byVehicle = const {}, this.unreported = const {}]);

  final Map<String, Map<String, LastValue>> byVehicle;

  /// By vehicle id, then key: the values its latest reading asked for and
  /// didn't get. One that comes back later leaves this.
  final Map<String, Map<String, UnreportedValue>> unreported;

  Map<String, LastValue> of(String vehicleId) =>
      byVehicle[vehicleId] ?? const {};

  Map<String, UnreportedValue> unreportedOf(String vehicleId) =>
      unreported[vehicleId] ?? const {};

  /// The vehicle's values for [keys] only, and the newest of them. A value
  /// it no longer sends says nothing about the car now.
  ({Map<String, LastValue> values, LastValue? newest}) sentOf(
    String vehicleId,
    Set<String> keys,
  ) {
    final values = {
      for (final MapEntry(:key, :value) in of(vehicleId).entries)
        if (keys.contains(key)) key: value,
    };
    LastValue? newest;
    for (final value in values.values) {
      if (newest == null || value.readAt.isAfter(newest.readAt)) {
        newest = value;
      }
    }
    return (values: values, newest: newest);
  }

  /// With [values], read [at] and sent in the reading numbered [seq], and
  /// [missing], asked for in the same reading but not reported.
  LastValues record(
    String vehicleId,
    Map<String, num> values,
    DateTime at, {
    required int seq,
    Map<String, Unreported> missing = const {},
  }) => LastValues(
    values.isEmpty
        ? byVehicle
        : {
            ...byVehicle,
            vehicleId: {
              ...of(vehicleId),
              for (final MapEntry(:key, :value) in values.entries)
                key: LastValue(value, at, seq: seq),
            },
          },
    {
      ...unreported,
      vehicleId: {
        for (final MapEntry(:key, :value) in unreportedOf(vehicleId).entries)
          if (!values.containsKey(key) && !missing.containsKey(key)) key: value,
        for (final MapEntry(:key, value: why) in missing.entries)
          key: UnreportedValue(why, at),
      },
    },
  );

  /// With [missing], asked for in a reading at [at] that sent nothing.
  LastValues noteUnreported(
    String vehicleId,
    Map<String, Unreported> missing,
    DateTime at,
  ) =>
      // No values, so no reading number to keep.
      record(vehicleId, const {}, at, seq: 0, missing: missing);

  /// Only the vehicles in [vehicleIds].
  LastValues only(Set<String> vehicleIds) => LastValues(
    {
      for (final MapEntry(:key, :value) in byVehicle.entries)
        if (vehicleIds.contains(key)) key: value,
    },
    {
      for (final MapEntry(:key, :value) in unreported.entries)
        if (vehicleIds.contains(key)) key: value,
    },
  );

  Map<String, Object?> toJson() => {
    'values': _valuesJson(),
    'unreported': {
      for (final MapEntry(key: vehicleId, value: missing) in unreported.entries)
        vehicleId: {
          for (final MapEntry(:key, :value) in missing.entries)
            key: {
              'reason': value.reason.name,
              'at': value.at.toIso8601String(),
            },
        },
    },
  };

  Map<String, Object?> _valuesJson() => {
    for (final MapEntry(key: vehicleId, value: values) in byVehicle.entries)
      vehicleId: {
        for (final MapEntry(:key, :value) in values.entries)
          key: {
            'value': value.value,
            'at': value.readAt.toIso8601String(),
            'seq': value.seq,
          },
      },
  };

  /// What [toJson] wrote. Entries that don't parse are left out.
  factory LastValues.fromJson(Map<String, Object?> json) => LastValues(
    switch (json['values']) {
      final Map<String, Object?> values => LastValues.fromValuesJson(
        values,
      ).byVehicle,
      _ => const {},
    },
    {
      if (json['unreported'] case final Map<String, Object?> byVehicle)
        for (final MapEntry(key: vehicleId, value: missing)
            in byVehicle.entries)
          if (missing is Map)
            vehicleId: {
              for (final MapEntry(:key, :value) in missing.entries)
                if ((key, value) case (
                  final String key,
                  {'reason': final String reason, 'at': final String at},
                ))
                  if ((
                        Unreported.values.asNameMap()[reason],
                        DateTime.tryParse(at),
                      )
                      case (final why?, final at?))
                    key: UnreportedValue(why, at),
            },
    },
  );

  /// The values alone, as kept before unreported ones were, by vehicle.
  /// Entries that don't parse are left out.
  factory LastValues.fromValuesJson(Map<String, Object?> json) => LastValues({
    for (final MapEntry(key: vehicleId, value: values) in json.entries)
      if (values is Map)
        vehicleId: {
          for (final MapEntry(:key, :value) in values.entries)
            if ((key, value) case (
              final String key,
              {
                'value': final num v,
                'at': final String at,
                'seq': final int seq,
              },
            ))
              if (DateTime.tryParse(at) case final readAt?)
                key: LastValue(v, readAt, seq: seq),
        },
  });
}

abstract interface class LastValuesStorage {
  Future<LastValues> load();
  Future<void> save(LastValues values);
}

/// Keeps the last values in one file in the app's private storage.
class FileLastValuesStorage implements LastValuesStorage {
  static const _fileName = 'last_values.json';

  /// The format [save] writes.
  static const _version = 3;

  /// No values saved, or none readable, is no values.
  @override
  Future<LastValues> load() async =>
      await readVersionedFile(_fileName, {
        // Before versions, the file was the vehicles alone.
        0: LastValues.fromValuesJson,
        1: (json) => _vehicles(json['vehicles']),
        2: (json) => _vehicles(json['data']),
        _version: (json) => switch (dataOf(json)) {
          final data? => LastValues.fromJson(data),
          null => null,
        },
      }) ??
      const LastValues();

  static LastValues? _vehicles(Object? json) => switch (json) {
    final Map<String, Object?> vehicles => LastValues.fromValuesJson(vehicles),
    _ => null,
  };

  @override
  Future<void> save(LastValues values) =>
      writeVersionedFile(_fileName, _version, values.toJson());
}
