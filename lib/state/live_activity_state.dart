import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session/car_state.dart';
import 'session_state.dart';
import 'trip_state.dart';

/// What's happening with a vehicle right now, from the session and the
/// trip together, worked out once for every screen.
@immutable
sealed class LiveActivity {
  const LiveActivity();

  /// The vehicle being connected to or connected, if any.
  String? get vehicleId => null;

  /// This activity if it's [id]'s, or none: what a screen about one
  /// vehicle shows.
  LiveActivity forVehicle(String id) =>
      vehicleId == id ? this : const NoActivity();
}

final class NoActivity extends LiveActivity {
  const NoActivity();
}

/// Connecting to the vehicle's adapter for the first time.
final class LiveConnecting extends LiveActivity {
  const LiveConnecting(this.vehicleId);

  @override
  final String vehicleId;
}

final class LiveConnected extends LiveActivity {
  const LiveConnected({
    required this.vehicleId,
    required this.since,
    required this.carState,
  });

  @override
  final String vehicleId;

  /// When the trip first reached the car, or, outside a trip, when the
  /// connection was made. A reconnect mid-trip doesn't change it.
  final DateTime since;
  final CarState carState;
}

/// A trip is running, but its adapter dropped and it's connecting again.
final class LiveReconnecting extends LiveActivity {
  const LiveReconnecting(this.vehicleId);

  @override
  final String vehicleId;
}

LiveActivity liveActivityFrom(SessionState session, TripState trip) {
  final running = trip is TripRunning ? trip : null;
  return switch (session) {
    SessionConnected(:final vehicleId, :final connectedAt, :final carState) =>
      LiveConnected(
        vehicleId: vehicleId,
        since: running?.vehicleId == vehicleId ? running!.since : connectedAt,
        carState: carState,
      ),
    SessionConnecting(:final vehicleId) =>
      running?.vehicleId == vehicleId
          ? LiveReconnecting(vehicleId)
          : LiveConnecting(vehicleId),
    SessionIdle() =>
      running == null
          ? const NoActivity()
          : LiveReconnecting(running.vehicleId),
  };
}

final liveActivityProvider = Provider<LiveActivity>(
  (ref) =>
      liveActivityFrom(ref.watch(sessionProvider), ref.watch(tripProvider)),
);
