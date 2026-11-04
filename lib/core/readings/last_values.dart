import 'package:flutter/foundation.dart';

import '../storage/app_files.dart';

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

/// The last value of each key every vehicle reported, by vehicle id.
///
/// A reading replaces only the keys it carries, so a value the car stops
/// reporting, say as it switches off, keeps the time it was last read.
@immutable
class LastValues {
  const LastValues([this.byVehicle = const {}]);

  final Map<String, Map<String, LastValue>> byVehicle;

  Map<String, LastValue> of(String vehicleId) =>
      byVehicle[vehicleId] ?? const {};

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

  LastValues record(
    String vehicleId,
    Map<String, num> values,
    DateTime at, {
    required int seq,
  }) => LastValues({
    ...byVehicle,
    vehicleId: {
      ...of(vehicleId),
      for (final MapEntry(:key, :value) in values.entries)
        key: LastValue(value, at, seq: seq),
    },
  });

  /// Only the vehicles in [vehicleIds].
  LastValues only(Set<String> vehicleIds) => LastValues({
    for (final MapEntry(:key, :value) in byVehicle.entries)
      if (vehicleIds.contains(key)) key: value,
  });

  Map<String, Object?> toJson() => {
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

  /// Entries that don't parse are left out.
  factory LastValues.fromJson(Map<String, Object?> json) => LastValues({
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
  static const _version = 2;

  /// No values saved, or none readable, is no values.
  @override
  Future<LastValues> load() async => switch (await readVersionedFile(
    _fileName,
    readers: {_version: _vehicles},
    before: {
      // Before versions, the file was the vehicles alone.
      0: LastValues.fromJson,
      1: (json) => _vehicles(json['vehicles']),
    },
  )) {
    SavedData(:final value) => value,
    NothingSaved() || UnreadableData() => const LastValues(),
  };

  static LastValues? _vehicles(Object? json) => switch (json) {
    final Map<String, Object?> vehicles => LastValues.fromJson(vehicles),
    _ => null,
  };

  @override
  Future<void> save(LastValues values) =>
      writeVersionedFile(_fileName, _version, values.toJson());
}
