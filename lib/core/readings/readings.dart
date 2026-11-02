import 'package:flutter/foundation.dart';

import '../obd/elm327.dart';
import '../obd/pids.dart';
import '../profiles/profile_reader.dart';
import '../profiles/signal_set.dart';
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
    this.fromProfile = false,
    this.category,
  });

  final String key;
  final String name;

  /// A compact label for tiles, e.g. "Fuel", when [name] is long.
  final String? shortName;

  /// What a tile says.
  String get label => shortName ?? name;
  final String unit;

  /// From the vehicle's profile rather than standard OBD-II. These aren't
  /// sent by default: a profile can have hundreds, mostly diagnostic.
  final bool fromProfile;

  /// For profile values, where OBDb files them, such as `Engine`.
  final String? category;
}

/// Every value Pitwall can send for this car: battery voltage, the standard
/// PIDs, and the profile's signals for [modelYear]. Keys are unique; a
/// signal the profile lists under several commands appears once.
List<ValueOption> valueOptions(SignalSet? profile, int? modelYear) {
  final options = <String, ValueOption>{
    batteryVoltageKey: const ValueOption(
      key: batteryVoltageKey,
      name: 'Battery voltage',
      shortName: 'Battery',
      unit: 'V',
    ),
    for (final definition in standardPids)
      definition.key: ValueOption(
        key: definition.key,
        name: definition.name,
        shortName: definition.shortName,
        unit: definition.unit,
      ),
  };
  if (profile != null && modelYear != null) {
    for (final command in profile.commandsFor(modelYear)) {
      for (final signal in command.signals) {
        options.putIfAbsent(
          signal.key,
          () => ValueOption(
            key: signal.key,
            name: signal.name,
            unit: signal.unit,
            fromProfile: true,
            category: signal.category,
          ),
        );
      }
    }
  }
  return options.values.toList();
}

/// A vehicle's values: every one it can send, and the ones it does.
@immutable
class VehicleValues {
  const VehicleValues._(this.options, this.sent, {required this.customised});

  factory VehicleValues.of(Vehicle vehicle, SignalSet? profile) {
    final options = valueOptions(profile, vehicle.modelYear);
    final chosen = vehicle.selectedKeys;
    return VehicleValues._(
      options,
      chosen ??
          {
            // Until the user chooses: the standard ones.
            for (final option in options)
              if (!option.fromProfile) option.key,
          },
      customised: chosen != null,
    );
  }

  final List<ValueOption> options;

  /// The keys it sends.
  final Set<String> sent;

  /// Whether the user chose them, so there's a choice to reset.
  final bool customised;

  /// What's sent with [key] turned [on] or off, to save as the choice.
  Set<String> withSent(String key, {required bool on}) =>
      on ? {...sent, key} : ({...sent}..remove(key));
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
