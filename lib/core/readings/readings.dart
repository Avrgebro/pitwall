import 'package:flutter/foundation.dart';

import '../obd/can_id.dart';
import '../obd/elm327.dart';
import '../obd/pids.dart';
import '../profiles/profile_reader.dart';
import '../profiles/signal_set.dart';
import '../profiles/stored_profile.dart';
import '../vehicles/vehicle.dart';
import 'metric.dart';
import 'unreported.dart';

/// A value Pitwall can send, for choosing what goes in the payload.
@immutable
class ValueOption {
  const ValueOption(this.metric, {this.category});

  final Metric metric;

  /// For profile values, where OBDb files them, such as `Engine`; null for
  /// the standard ones.
  final String? category;

  /// From the vehicle's profile rather than standard OBD-II. These aren't
  /// sent by default: a profile can have hundreds, mostly diagnostic.
  bool get fromProfile => category != null;
}

/// Every value Pitwall can send for this car: battery voltage, the standard
/// PIDs, and the values [profile] says it can read, each its own metric.
List<ValueOption> valueOptions(ProfileSummary? profile) => [
  const ValueOption(Metrics.batteryVoltage),
  for (final definition in standardPids) ValueOption(definition.metric),
  for (final signal in profile?.readable ?? const <ProfileSignal>[])
    ValueOption(signal.metric, category: signal.category),
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
      // Until its adapter is known, as if it could read them all.
      (LoadedProfile(:final signals), final year?) => signals.summaryFor(
        year,
        flowControl: vehicle.adapter?.setsFlowControl ?? true,
      ),
      _ => null,
    };
    final options = valueOptions(profile);
    final offered = {for (final option in options) option.metric.key};
    final chosen =
        vehicle.selectedKeys ??
        {
          // Until the user chooses: the standard ones.
          for (final option in options)
            if (!option.fromProfile) option.metric.key,
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
/// requests those keys need are sent; why any of them didn't come back is
/// said too.
Future<ValuesRead> readValues(
  Elm327 elm, {
  required Set<String> keys,
  required Set<int> supportedPids,
  SignalSet? profile,
  int? modelYear,
}) async {
  final values = <String, double>{};
  final unreported = <String, Unreported>{};
  final unanswered = <String, CanId>{};
  final answered = <CanId>{};
  if (keys.contains(Metrics.batteryVoltage.key)) {
    switch (await elm.readBatteryVoltage()) {
      case final voltage?:
        values[Metrics.batteryVoltage.key] = voltage;
      case null:
        unreported[Metrics.batteryVoltage.key] = Unreported.unavailable;
    }
  }
  for (final definition in standardPids) {
    final key = definition.metric.key;
    if (!keys.contains(key)) continue;
    if (!supportedPids.contains(definition.pid)) {
      // Only news once the car has said what it supports.
      if (supportedPids.isNotEmpty) unreported[key] = Unreported.unsupported;
      continue;
    }
    // Standard values go to every module; the engine's answers.
    switch (await elm.requestPid(definition.pid)) {
      case null:
        unanswered[key] = CanId.broadcast;
      case final data when data.length < definition.length:
        answered.add(CanId.broadcast);
        unreported[key] = Unreported.notInReply;
      case final data:
        answered.add(CanId.broadcast);
        values[key] = definition.decode(data);
    }
  }
  if (profile != null && modelYear != null) {
    final fromProfile = await readProfile(elm, profile, modelYear, keys: keys);
    values.addAll(fromProfile.values);
    unreported.addAll(fromProfile.unreported);
    unanswered.addAll(fromProfile.unanswered);
    answered.addAll(fromProfile.answered);
  }
  return (
    values: values,
    unreported: unreported,
    unanswered: unanswered,
    answered: answered,
  );
}
