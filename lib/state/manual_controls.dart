import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/vehicles/vehicle.dart';
import 'infrastructure.dart';
import 'session_state.dart';
import 'settings_state.dart';
import 'trip_state.dart';

/// What Developer tools can do by hand, from the session and the trip
/// together.
@immutable
sealed class ManualControls {
  const ManualControls();
}

/// A trip drives the session, and manual controls would fight it: only
/// stopping it, unless it's already ending.
final class TripControls extends ManualControls {
  const TripControls({required this.canStop});

  final bool canStop;
}

/// Connected by hand: read now, unless the adapter is busy, or disconnect.
final class SessionControls extends ManualControls {
  const SessionControls({required this.canRead});

  final bool canRead;
}

/// A connection is being made; nothing to do but wait.
final class WaitingControls extends ManualControls {
  const WaitingControls();
}

/// Nothing running: connect to [vehicle] by hand, or start a trip for it
/// as if the car's Bluetooth connected.
final class IdleControls extends ManualControls {
  const IdleControls(this.vehicle, this.adapter, {this.problem});

  final Vehicle vehicle;

  /// The vehicle's adapter, which it has to have to connect.
  final VehicleAdapter adapter;

  /// Why the last connection ended, if it failed or was lost.
  final ConnectionProblem? problem;
}

/// Nothing running, and nothing can start until [blocker] is dealt with.
final class BlockedControls extends ManualControls {
  const BlockedControls(this.blocker);

  final IdleBlocker blocker;
}

/// Why nothing can be started by hand.
enum IdleBlocker { noVehicle, needsAdapter, bluetoothOff }

/// The controls for [vehicle], or none, given the session and the trip.
/// Bluetooth is assumed on until Android says otherwise, so nothing
/// flashes.
ManualControls manualControlsFrom(
  SessionState session,
  TripState trip, {
  required Vehicle? vehicle,
  bool bluetoothOn = true,
}) => switch (trip) {
  TripIdle() => switch (session) {
    SessionConnected(:final busy) => SessionControls(canRead: !busy),
    SessionConnecting() => const WaitingControls(),
    SessionIdle(:final problem) => switch (vehicle) {
      null => const BlockedControls(IdleBlocker.noVehicle),
      Vehicle(adapter: null) => const BlockedControls(IdleBlocker.needsAdapter),
      _ when !bluetoothOn => const BlockedControls(IdleBlocker.bluetoothOff),
      final Vehicle ready && Vehicle(:final adapter?) => IdleControls(
        ready,
        adapter,
        problem: problem,
      ),
    },
  },
  TripEnding() => const TripControls(canStop: false),
  TripConnecting() || TripRunning() => const TripControls(canStop: true),
};

/// The controls for the vehicle with this id, or for none.
final manualControlsProvider = Provider.family<ManualControls, String?>(
  (ref, vehicleId) => manualControlsFrom(
    ref.watch(sessionProvider),
    ref.watch(tripProvider),
    vehicle: vehicleId == null ? null : ref.watch(vehicleProvider(vehicleId)),
    bluetoothOn: ref.watch(bluetoothOnProvider).value ?? true,
  ),
);
