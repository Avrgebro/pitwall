/// The words the session, the trip, the keeper, Home and Developer tools
/// share: how a step went, and what state the session is in.
library;

import 'package:flutter/foundation.dart';

import '../core/obd/trouble_codes.dart';
import '../core/session/car_reading.dart';
import '../core/session/car_state.dart';
import '../core/vehicles/vehicle.dart';

/// Why the session isn't connected: the connection was tried and failed,
/// or it was lost.
enum ConnectionProblem {
  /// Bluetooth permission isn't granted.
  permissionDenied,

  /// The adapter couldn't be reached over Bluetooth.
  connectFailed,

  /// The adapter dropped the connection.
  disconnected,

  /// The adapter reported an error or stopped answering.
  adapterError,
}

/// Why the session didn't do what was asked, without trying.
enum Refusal {
  /// The vehicle has no adapter chosen.
  noAdapter,

  /// Another connection is being made or is open.
  inUse,

  /// Not connected, so nothing could be asked.
  notConnected,

  /// Another operation is running on the adapter.
  busy,

  /// The connected vehicle was deleted, so there's nothing to read for.
  vehicleRemoved,
}

/// How a step on the session ended: done, refused without trying, or
/// failed, which leaves the session idle.
sealed class StepOutcome<T> {
  const StepOutcome();
}

final class StepDone<T> extends StepOutcome<T> {
  const StepDone(this.value);

  final T value;
}

final class StepRefused<T> extends StepOutcome<T> {
  const StepRefused(this.refusal);

  final Refusal refusal;
}

final class StepFailed<T> extends StepOutcome<T> {
  const StepFailed(this.problem);

  final ConnectionProblem problem;
}

/// How a connection attempt ended: done with the live session.
typedef ConnectResult = StepOutcome<SessionConnected>;

/// What asking a vehicle's car found, with the vehicle it was asked for.
@immutable
final class VehicleReading {
  const VehicleReading(this.vehicle, this.reading, {this.troubleCodes});

  final Vehicle vehicle;
  final CarReading reading;

  /// The car's trouble codes as last read, if the vehicle sends them and
  /// the car answered.
  final TroubleCodes? troubleCodes;
}

/// How asking the car something ended: done with what it said.
typedef ReadOutcome = StepOutcome<VehicleReading>;

/// A connection to a vehicle's adapter: none, being made, or live. Each
/// stage carries only what's known in it.
@immutable
sealed class SessionState {
  const SessionState();
}

final class SessionIdle extends SessionState {
  const SessionIdle({this.problem});

  /// Why the last connection failed or was lost, if it was.
  final ConnectionProblem? problem;
}

final class SessionConnecting extends SessionState {
  const SessionConnecting(this.vehicleId);

  final String vehicleId;
}

final class SessionConnected extends SessionState {
  const SessionConnected({
    required this.vehicleId,
    required this.connectedAt,
    this.adapterVersion,
    this.setsFlowControl = true,
    this.supportedPids = const {},
    this.carState = CarState.unknown,
    this.busy = false,
  });

  final String vehicleId;
  final DateTime connectedAt;
  final String? adapterVersion;

  /// Whether the adapter can set flow control; see `Elm327.setsFlowControl`.
  final bool setsFlowControl;
  final Set<int> supportedPids;
  final CarState carState;

  /// An operation is running on the adapter.
  final bool busy;

  SessionConnected copyWith({
    Set<int>? supportedPids,
    CarState? carState,
    bool? busy,
  }) => SessionConnected(
    vehicleId: vehicleId,
    connectedAt: connectedAt,
    adapterVersion: adapterVersion,
    setsFlowControl: setsFlowControl,
    supportedPids: supportedPids ?? this.supportedPids,
    carState: carState ?? this.carState,
    busy: busy ?? this.busy,
  );
}
