import 'dart:math';

import 'package:flutter/foundation.dart';

import '../bluetooth/adapter_type.dart';
import '../bluetooth/bluetooth_address.dart';
import '../bluetooth/bluetooth_gateway.dart';
import '../profiles/profile_ref.dart';
import 'device_id.dart';

/// What starts a trip in a vehicle.
enum TripStart {
  /// The phone connecting to the car's own Bluetooth (head unit).
  carBluetooth,

  /// A Bluetooth LE adapter that sleeps while the car is off waking up, as
  /// Android notices it appear. Only for adapters that do sleep: one that
  /// doesn't would start a trip whenever the phone passes the parked car.
  adapterWakes,
}

/// Something a vehicle lacks before its trips start and send on their own.
enum VehicleNeed {
  /// No adapter is chosen.
  adapter,

  /// Its trips start from the car's Bluetooth, but none is chosen.
  headUnit,

  /// Its trips start when the adapter wakes, which only a Bluetooth LE
  /// adapter can be watched for.
  bluetoothLeAdapter,

  /// Its trips start when the adapter wakes, but Android hasn't been asked
  /// to watch for it, which the user confirms once.
  adapterWatch;

  /// Whether this is about how trips start, rather than the adapter.
  bool get isTripStart => this != adapter;
}

/// The vehicle's OBD adapter: its Bluetooth address, the name the phone
/// knows it by, and how the phone talks to it.
@immutable
class VehicleAdapter {
  const VehicleAdapter({
    required this.address,
    required this.name,
    required this.type,
    this.setsFlowControl,
    this.watched = false,
  });

  /// [device], chosen as the adapter. What it can do isn't known until
  /// it's connected to, and Android isn't watching for it yet.
  VehicleAdapter.of(BluetoothDevice device)
    : this(address: device.address, name: device.name, type: device.type);

  final String address;
  final String name;
  final AdapterType type;

  /// Whether it can set flow control, as found the last time it was
  /// connected to; null before then. Some profile values need it.
  final bool? setsFlowControl;

  /// Whether Android watches for it to wake, as the user confirmed; see
  /// [TripStart.adapterWakes]. Another adapter starts unwatched.
  final bool watched;

  /// Whether this is the adapter at [address].
  bool isAt(String address) => sameAddress(this.address, address);

  /// This adapter, chosen again as [device]: what it can do is kept, and
  /// its name and how it connects are taken as Android reports them now.
  /// Only a Bluetooth LE adapter is watched for.
  VehicleAdapter chosenAgain(BluetoothDevice device) => VehicleAdapter(
    address: address,
    name: device.name,
    type: device.type,
    setsFlowControl: setsFlowControl,
    watched: watched && device.type == AdapterType.ble,
  );

  VehicleAdapter withFlowControl(bool sets) => VehicleAdapter(
    address: address,
    name: name,
    type: type,
    setsFlowControl: sets,
    watched: watched,
  );

  VehicleAdapter withWatched(bool watched) => VehicleAdapter(
    address: address,
    name: name,
    type: type,
    setsFlowControl: setsFlowControl,
    watched: watched,
  );

  @override
  bool operator ==(Object other) =>
      other is VehicleAdapter &&
      other.address == address &&
      other.name == name &&
      other.type == type &&
      other.setsFlowControl == setsFlowControl &&
      other.watched == watched;

  @override
  int get hashCode =>
      Object.hash(address, name, type, setsFlowControl, watched);
}

/// The car's own Bluetooth (its head unit), whose connection can start
/// the vehicle's trips.
@immutable
class HeadUnit {
  const HeadUnit({required this.address, required this.name});

  final String address;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is HeadUnit && other.address == address && other.name == name;

  @override
  int get hashCode => Object.hash(address, name);
}

/// One car: its adapter, the name sent in payloads, what starts its trips,
/// its optional OBDb profile and the values to send.
@immutable
class Vehicle {
  const Vehicle({
    required this.id,
    this.name = defaultName,
    this.adapter,
    this.tripStart = TripStart.carBluetooth,
    this.headUnit,
    this.modelYear,
    this.selectedKeys,
    this.profile,
    this.lastSeen,
    this.sendsTroubleCodes = true,
  });

  /// A new vehicle with a fresh id.
  factory Vehicle.create({String name = defaultName}) =>
      Vehicle(id: _newId(), name: name);

  /// A name with nothing to make an id from gives the same `device`.
  static const defaultName = fallbackDeviceId;

  /// Stable id, used to name the vehicle's profile file.
  final String id;

  /// The name the user gave the vehicle, shown in the app.
  final String name;

  /// Sent as `device` in every payload, so one receiver can tell several
  /// cars apart. Derived from [name]; renaming the vehicle changes it.
  String get deviceId => deviceIdFor(name);

  final VehicleAdapter? adapter;

  final TripStart tripStart;

  /// The car's Bluetooth, for [TripStart.carBluetooth].
  final HeadUnit? headUnit;

  /// The head unit whose connection starts this vehicle's trips, if its
  /// trips start that way and one is chosen.
  String? get startingHeadUnit =>
      tripStart == TripStart.carBluetooth ? headUnit?.address : null;

  /// The adapter whose waking starts this vehicle's trips, if its trips
  /// start that way and Android watches for it.
  String? get startingAdapter => switch ((tripStart, adapter)) {
    (
      TripStart.adapterWakes,
      VehicleAdapter(type: AdapterType.ble, watched: true, :final address),
    ) =>
      address,
    _ => null,
  };

  /// What the vehicle lacks before it works on its own; empty when
  /// nothing does. The adapter comes first.
  List<VehicleNeed> get needs => [
    if (adapter == null) VehicleNeed.adapter,
    ...switch (tripStart) {
      TripStart.carBluetooth when headUnit == null => [VehicleNeed.headUnit],
      TripStart.carBluetooth => const <VehicleNeed>[],
      TripStart.adapterWakes => switch (adapter) {
        null => const <VehicleNeed>[],
        VehicleAdapter(type: AdapterType.classic) => [
          VehicleNeed.bluetoothLeAdapter,
        ],
        VehicleAdapter(watched: false) => [VehicleNeed.adapterWatch],
        VehicleAdapter() => const <VehicleNeed>[],
      },
    },
  ];

  /// Picks which of the profile's signals apply.
  final int? modelYear;

  /// Payload keys to send. Null means the default set.
  final Set<String>? selectedKeys;

  /// The imported OBDb profile, or null without one.
  final ProfileRef? profile;

  /// When the vehicle's adapter last connected.
  final DateTime? lastSeen;

  /// Whether readings carry the car's trouble codes and check-engine
  /// light. On unless turned off: cheap to read, and worth knowing.
  final bool sendsTroubleCodes;

  /// Whether its adapter can set flow control, as found the last time it
  /// was connected to. Until then, as if it could: what it can read is
  /// only narrowed once it's known.
  bool get setsFlowControl => adapter?.setsFlowControl ?? true;

  /// A copy with the given fields changed. What can be cleared has its own
  /// method: [withProfile] and [withSelectedKeys].
  Vehicle copyWith({
    String? name,
    VehicleAdapter? adapter,
    TripStart? tripStart,
    HeadUnit? headUnit,
    int? modelYear,
    DateTime? lastSeen,
    bool? sendsTroubleCodes,
  }) => Vehicle(
    id: id,
    name: name ?? this.name,
    adapter: adapter ?? this.adapter,
    tripStart: tripStart ?? this.tripStart,
    headUnit: headUnit ?? this.headUnit,
    modelYear: modelYear ?? this.modelYear,
    selectedKeys: selectedKeys,
    profile: profile,
    lastSeen: lastSeen ?? this.lastSeen,
    sendsTroubleCodes: sendsTroubleCodes ?? this.sendsTroubleCodes,
  );

  /// With [profile], or none, read for [modelYear], which only matters
  /// with a profile.
  Vehicle withProfile(ProfileRef? profile, {required int? modelYear}) =>
      Vehicle(
        id: id,
        name: name,
        adapter: adapter,
        tripStart: tripStart,
        headUnit: headUnit,
        modelYear: modelYear,
        selectedKeys: selectedKeys,
        profile: profile,
        lastSeen: lastSeen,
        sendsTroubleCodes: sendsTroubleCodes,
      );

  /// Sending [keys], or the default set with none.
  Vehicle withSelectedKeys(Set<String>? keys) => Vehicle(
    id: id,
    name: name,
    adapter: adapter,
    tripStart: tripStart,
    headUnit: headUnit,
    modelYear: modelYear,
    selectedKeys: keys,
    profile: profile,
    lastSeen: lastSeen,
    sendsTroubleCodes: sendsTroubleCodes,
  );

  /// The same keys as earlier versions, so saved vehicles keep loading.
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'adapterAddress': adapter?.address,
    'adapterName': adapter?.name,
    'adapterType': adapter?.type.name,
    'adapterSetsFlowControl': adapter?.setsFlowControl,
    'adapterWatched': adapter?.watched,
    'tripStart': tripStart.name,
    'headUnitAddress': headUnit?.address,
    'headUnitName': headUnit?.name,
    'modelYear': modelYear,
    'selectedKeys': selectedKeys?.toList()?..sort(),
    'profileName': profile?.name,
    'profileImportedAt': profile?.importedAt?.toUtc().toIso8601String(),
    'lastSeen': lastSeen?.toUtc().toIso8601String(),
    'sendsTroubleCodes': sendsTroubleCodes,
  };

  /// Tolerates missing or wrongly typed fields, falling back to defaults.
  /// A device without a name goes by its address.
  factory Vehicle.fromJson(Map<String, Object?> json) => Vehicle(
    id: _string(json['id']) ?? _newId(),
    name: switch (json['name']) {
      final String name when name.isNotEmpty => name,
      _ => defaultName,
    },
    adapter: switch (_string(json['adapterAddress'])) {
      final address? => VehicleAdapter(
        address: address,
        name: _string(json['adapterName']) ?? address,
        type:
            AdapterType.values.asNameMap()[json['adapterType']] ??
            AdapterType.classic,
        setsFlowControl: switch (json['adapterSetsFlowControl']) {
          final bool sets => sets,
          _ => null,
        },
        watched: json['adapterWatched'] == true,
      ),
      null => null,
    },
    tripStart:
        TripStart.values.asNameMap()[json['tripStart']] ??
        TripStart.carBluetooth,
    headUnit: switch (_string(json['headUnitAddress'])) {
      final address? => HeadUnit(
        address: address,
        name: _string(json['headUnitName']) ?? address,
      ),
      null => null,
    },
    modelYear: switch (json['modelYear']) {
      final num year => year.toInt(),
      _ => null,
    },
    selectedKeys: switch (json['selectedKeys']) {
      final List<Object?> keys => {...keys.whereType<String>()},
      _ => null,
    },
    profile: switch (_string(json['profileName'])) {
      final name? => ProfileRef(
        name,
        importedAt: _time(json['profileImportedAt']),
      ),
      null => null,
    },
    lastSeen: _time(json['lastSeen']),
    // On for vehicles saved before it was a choice.
    sendsTroubleCodes: json['sendsTroubleCodes'] != false,
  );

  static String _newId() {
    final random = Random.secure();
    return List.generate(
      8,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}

String? _string(Object? value) => value is String ? value : null;

DateTime? _time(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;
