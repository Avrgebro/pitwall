import 'package:flutter/foundation.dart';

import '../obd/elm327.dart';
import '../obd/pids.dart';
import '../profiles/profile_reader.dart';
import '../profiles/signal_set.dart';
import '../profiles/stored_profile.dart';
import '../vehicles/vehicle.dart';

/// Payload key for the voltage the adapter measures (`ATRV`).
const batteryVoltageKey = 'battery_v';

/// A value Pitwall can send, for choosing what goes in the payload.
class ValueOption {
  const ValueOption({
    required this.key,
    required this.name,
    required this.unit,
    this.shortName,
    this.category,
  });

  final String key;
  final String name;

  /// A compact label for tiles, e.g. "Fuel", when [name] is long.
  final String? shortName;

  /// What a tile says.
  String get label => shortName ?? name;
  final String unit;

  /// For profile values, where OBDb files them, such as `Engine`; null for
  /// the standard ones.
  final String? category;

  /// From the vehicle's profile rather than standard OBD-II. These aren't
  /// sent by default: a profile can have hundreds, mostly diagnostic.
  bool get fromProfile => category != null;
}

/// Every value Pitwall can send for this car: battery voltage, the standard
/// PIDs, and the values [profile] says it can read.
List<ValueOption> valueOptions(ProfileSummary? profile) => [
  const ValueOption(
    key: batteryVoltageKey,
    name: 'Battery voltage',
    shortName: 'Battery',
    unit: 'V',
  ),
  for (final definition in standardPids)
    ValueOption(
      key: definition.key,
      name: definition.name,
      shortName: definition.shortName,
      unit: definition.unit,
    ),
  for (final signal in profile?.readable ?? const <ProfileSignal>[])
    ValueOption(
      key: signal.key,
      name: signal.name,
      unit: signal.unit,
      category: signal.category,
    ),
];

/// A vehicle's values: every one it can send, and the ones it does.
@immutable
class VehicleValues {
  const VehicleValues._(
    this.vehicle,
    this.stored,
    this.options,
    this.sent,
    this._chosen, {
    required this.customised,
    required this.profile,
  });

  /// [stored] is null while the profile loads.
  factory VehicleValues.of(Vehicle vehicle, StoredProfile? stored) {
    final year = vehicle.modelYear;
    final profile = switch ((stored, year)) {
      (LoadedProfile(:final signals), final year?) => signals.summaryFor(year),
      _ => null,
    };
    final options = valueOptions(profile);
    final offered = {for (final option in options) option.key};
    final chosen =
        vehicle.selectedKeys ??
        {
          // Until the user chooses: the standard ones.
          for (final option in options)
            if (!option.fromProfile) option.key,
        };
    return VehicleValues._(
      vehicle,
      stored,
      options,
      chosen.intersection(offered),
      chosen,
      customised: vehicle.selectedKeys != null,
      profile: profile,
    );
  }

  final Vehicle vehicle;

  /// The vehicle's profile as found on the phone, or null while it loads.
  final StoredProfile? stored;

  final List<ValueOption> options;

  /// What the profile adds for the vehicle's model year, once both are
  /// known.
  final ProfileSummary? profile;

  /// The keys it sends: the chosen ones it offers.
  final Set<String> sent;

  /// Everything chosen, including keys not offered right now, as a
  /// profile's while it loads or after it was removed (Undo brings it
  /// back). Kept as it is, so those choices survive.
  final Set<String> _chosen;

  /// Whether the user chose them, so there's a choice to reset.
  final bool customised;

  /// The choice with [key] turned [on] or off, to save.
  Set<String> withSent(String key, {required bool on}) =>
      on ? {..._chosen, key} : ({..._chosen}..remove(key));
}

/// Reads the values in [keys]: battery voltage from the adapter, standard
/// PIDs the car supports, and profile signals for [modelYear]. Only the
/// requests those keys need are sent.
Future<Map<String, double>> readValues(
  Elm327 elm, {
  required Set<String> keys,
  required Set<int> supportedPids,
  SignalSet? profile,
  int? modelYear,
}) async {
  final standard = <String, double>{};
  if (keys.contains(batteryVoltageKey)) {
    final voltage = await elm.readBatteryVoltage();
    if (voltage != null) standard[batteryVoltageKey] = voltage;
  }
  for (final definition in standardPids) {
    if (!keys.contains(definition.key)) continue;
    if (!supportedPids.contains(definition.pid)) continue;
    final value = await elm.read(definition);
    if (value != null) standard[definition.key] = value;
  }
  final fromProfile = profile != null && modelYear != null
      ? await readProfile(elm, profile, modelYear, keys: keys)
      : <String, double>{};
  return {...standard, ...fromProfile};
}
