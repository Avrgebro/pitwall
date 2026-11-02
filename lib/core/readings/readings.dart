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
    required this.shortName,
    required this.unit,
    this.fromProfile = false,
    this.category,
  });

  final String key;
  final String name;

  /// Compact label for tiles, e.g. "Fuel".
  final String shortName;
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
            shortName: signal.name,
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

/// The keys [vehicle] sends: the ones the user chose, or the defaults.
Set<String> keysToSend(Vehicle vehicle, List<ValueOption> options) =>
    vehicle.selectedKeys ?? defaultKeys(options);

/// The keys sent when the user hasn't chosen any: the standard ones.
Set<String> defaultKeys(List<ValueOption> options) => {
  for (final option in options)
    if (!option.fromProfile) option.key,
};

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
