import 'dart:math';

import 'device_id.dart';

/// How the phone talks to the adapter.
enum AdapterType {
  /// Bluetooth serial (RFCOMM). Android only.
  classic,

  /// Bluetooth Low Energy.
  ble,
}

/// What starts a trip in a vehicle.
enum TripStart {
  /// The phone connecting to the car's own Bluetooth (head unit).
  carBluetooth,

  /// Android detecting that the phone is in a moving vehicle. Not built
  /// yet.
  drivingDetection,
}

/// One car: its adapter, the name sent in payloads, what starts its trips,
/// its optional OBDb profile and the values to send.
class Vehicle {
  const Vehicle({
    required this.id,
    this.name = defaultName,
    this.adapterAddress,
    this.adapterName,
    this.adapterType = AdapterType.classic,
    this.tripStart = TripStart.carBluetooth,
    this.headUnitAddress,
    this.headUnitName,
    this.modelYear,
    this.selectedKeys,
    this.profileName,
    this.profileImportedAt,
    this.lastSeen,
  });

  /// A new vehicle with a fresh id.
  factory Vehicle.create({String name = defaultName}) =>
      Vehicle(id: _newId(), name: name);

  static const defaultName = 'my-car';

  /// Stable id, used to name the vehicle's profile file.
  final String id;

  /// The name the user gave the vehicle, shown in the app.
  final String name;

  /// Sent as `device` in every payload, so one receiver can tell several
  /// cars apart. Derived from [name]; renaming the vehicle changes it.
  String get deviceId => deviceIdFor(name);

  /// Bluetooth address of the vehicle's OBD adapter.
  final String? adapterAddress;
  final String? adapterName;
  final AdapterType adapterType;

  final TripStart tripStart;

  /// The car's Bluetooth head unit, for [TripStart.carBluetooth].
  final String? headUnitAddress;
  final String? headUnitName;

  /// The head unit whose connection starts this vehicle's trips, if its
  /// trips start that way and one is chosen.
  String? get startingHeadUnit =>
      tripStart == TripStart.carBluetooth ? headUnitAddress : null;

  /// Whether something will start this vehicle's trips on its own.
  bool get hasTripStart => startingHeadUnit != null;

  /// Picks which of the profile's signals apply.
  final int? modelYear;

  /// Payload keys to send. Null means the default set.
  final Set<String>? selectedKeys;

  /// File name the profile was imported from, or null without a profile.
  final String? profileName;
  final DateTime? profileImportedAt;

  /// When the vehicle's adapter last connected.
  final DateTime? lastSeen;

  Vehicle copyWith({
    String? name,
    Object? adapterAddress = _keep,
    Object? adapterName = _keep,
    AdapterType? adapterType,
    TripStart? tripStart,
    Object? headUnitAddress = _keep,
    Object? headUnitName = _keep,
    Object? modelYear = _keep,
    Object? selectedKeys = _keep,
    Object? profileName = _keep,
    Object? profileImportedAt = _keep,
    DateTime? lastSeen,
  }) => Vehicle(
    id: id,
    name: name ?? this.name,
    adapterAddress: adapterAddress == _keep
        ? this.adapterAddress
        : adapterAddress as String?,
    adapterName: adapterName == _keep
        ? this.adapterName
        : adapterName as String?,
    adapterType: adapterType ?? this.adapterType,
    tripStart: tripStart ?? this.tripStart,
    headUnitAddress: headUnitAddress == _keep
        ? this.headUnitAddress
        : headUnitAddress as String?,
    headUnitName: headUnitName == _keep
        ? this.headUnitName
        : headUnitName as String?,
    modelYear: modelYear == _keep ? this.modelYear : modelYear as int?,
    selectedKeys: selectedKeys == _keep
        ? this.selectedKeys
        : selectedKeys as Set<String>?,
    profileName: profileName == _keep
        ? this.profileName
        : profileName as String?,
    profileImportedAt: profileImportedAt == _keep
        ? this.profileImportedAt
        : profileImportedAt as DateTime?,
    lastSeen: lastSeen ?? this.lastSeen,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'adapterAddress': adapterAddress,
    'adapterName': adapterName,
    'adapterType': adapterType.name,
    'tripStart': tripStart.name,
    'headUnitAddress': headUnitAddress,
    'headUnitName': headUnitName,
    'modelYear': modelYear,
    'selectedKeys': selectedKeys?.toList()?..sort(),
    'profileName': profileName,
    'profileImportedAt': profileImportedAt?.toUtc().toIso8601String(),
    'lastSeen': lastSeen?.toUtc().toIso8601String(),
  };

  /// Tolerates missing or wrongly typed fields, falling back to defaults,
  /// so older saved data keeps loading.
  factory Vehicle.fromJson(Map<String, Object?> json) => Vehicle(
    id: _string(json['id']) ?? _newId(),
    name: switch (json['name'] ?? json['deviceName']) {
      final String name when name.isNotEmpty => name,
      _ => defaultName,
    },
    adapterAddress: _string(json['adapterAddress']),
    adapterName: _string(json['adapterName']),
    adapterType:
        AdapterType.values.asNameMap()[json['adapterType']] ??
        AdapterType.classic,
    tripStart:
        TripStart.values.asNameMap()[json['tripStart']] ??
        TripStart.carBluetooth,
    headUnitAddress: _string(json['headUnitAddress']),
    headUnitName: _string(json['headUnitName']),
    modelYear: switch (json['modelYear']) {
      final num year => year.toInt(),
      _ => null,
    },
    selectedKeys: switch (json['selectedKeys']) {
      final List<Object?> keys => {...keys.whereType<String>()},
      _ => null,
    },
    profileName: _string(json['profileName']),
    profileImportedAt: _time(json['profileImportedAt']),
    lastSeen: _time(json['lastSeen']),
  );

  static String _newId() {
    final random = Random.secure();
    return List.generate(
      8,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}

const _keep = Object();

String? _string(Object? value) => value is String ? value : null;

DateTime? _time(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;
