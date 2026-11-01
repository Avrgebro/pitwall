import 'dart:math';

/// One car: its adapter, the name sent in payloads, its optional OBDb
/// profile and the values to send. The vehicle in use is picked by which
/// adapter connects.
class Vehicle {
  const Vehicle({
    required this.id,
    this.name = defaultName,
    this.adapterAddress,
    this.adapterName,
    this.modelYear,
    this.selectedKeys,
    this.profileName,
  });

  /// A new vehicle with a fresh id.
  factory Vehicle.create({String name = defaultName}) =>
      Vehicle(id: _newId(), name: name);

  static const defaultName = 'my-car';

  /// Stable id, used to name the vehicle's profile file.
  final String id;

  /// Sent as `device` in every payload, so one receiver can tell several
  /// cars apart.
  final String name;

  /// Bluetooth address of the vehicle's OBD adapter.
  final String? adapterAddress;
  final String? adapterName;

  /// Picks which of the profile's signals apply.
  final int? modelYear;

  /// Payload keys to send. Null means the default set.
  final Set<String>? selectedKeys;

  /// File name the profile was imported from, or null without a profile.
  final String? profileName;

  Vehicle copyWith({
    String? name,
    Object? adapterAddress = _keep,
    Object? adapterName = _keep,
    Object? modelYear = _keep,
    Object? selectedKeys = _keep,
    Object? profileName = _keep,
  }) => Vehicle(
    id: id,
    name: name ?? this.name,
    adapterAddress: adapterAddress == _keep
        ? this.adapterAddress
        : adapterAddress as String?,
    adapterName: adapterName == _keep
        ? this.adapterName
        : adapterName as String?,
    modelYear: modelYear == _keep ? this.modelYear : modelYear as int?,
    selectedKeys: selectedKeys == _keep
        ? this.selectedKeys
        : selectedKeys as Set<String>?,
    profileName: profileName == _keep
        ? this.profileName
        : profileName as String?,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'adapterAddress': adapterAddress,
    'adapterName': adapterName,
    'modelYear': modelYear,
    'selectedKeys': selectedKeys?.toList()?..sort(),
    'profileName': profileName,
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
    modelYear: switch (json['modelYear']) {
      final num year => year.toInt(),
      _ => null,
    },
    selectedKeys: switch (json['selectedKeys']) {
      final List<Object?> keys => {...keys.whereType<String>()},
      _ => null,
    },
    profileName: _string(json['profileName']),
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
