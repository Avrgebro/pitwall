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

  /// Whether it's about the vehicle [id].
  bool isAbout(String id);

  /// This activity if it's about [id], or none: what a screen about one
  /// vehicle shows.
  LiveActivity forVehicle(String id) => isAbout(id) ? this : const NoActivity();
}

final class NoActivity extends LiveActivity {
  const NoActivity();

  @override
  bool isAbout(String id) => false;
}

/// A trip is looking for an adapter, between connection attempts, among
/// the vehicles it's for.
final class LiveSearching extends LiveActivity {
  const LiveSearching(this.vehicleIds);

  final Set<String> vehicleIds;

  @override
  bool isAbout(String id) => vehicleIds.contains(id);
}

/// Activity with one vehicle's adapter.
sealed class VehicleActivity extends LiveActivity {
  const VehicleActivity(this.vehicleId);

  final String vehicleId;

  @override
  bool isAbout(String id) => id == vehicleId;
}

/// Connecting to the vehicle's adapter for the first time.
final class LiveConnecting extends VehicleActivity {
  const LiveConnecting(super.vehicleId);
}

final class LiveConnected extends VehicleActivity {
  const LiveConnected({
    required String vehicleId,
    required this.since,
    required this.carState,
    this.inTrip = false,
  }) : super(vehicleId);

  /// When the trip first reached the car, or, outside a trip, when the
  /// connection was made. A reconnect mid-trip doesn't change it.
  final DateTime since;

  /// Part of a trip, rather than a connection made by hand.
  final bool inTrip;
  final CarState carState;
}

/// A trip is running, but its adapter dropped and it's connecting again.
final class LiveReconnecting extends VehicleActivity {
  const LiveReconnecting(super.vehicleId);
}

LiveActivity liveActivityFrom(SessionState session, TripState trip) => switch ((
  session,
  trip,
)) {
  (
    SessionConnected(:final vehicleId, :final connectedAt, :final carState),
    _,
  ) =>
    switch (trip) {
      TripRunning(vehicleId: final tripVehicle, :final since)
          when tripVehicle == vehicleId =>
        LiveConnected(
          vehicleId: vehicleId,
          since: since,
          carState: carState,
          inTrip: true,
        ),
      _ => LiveConnected(
        vehicleId: vehicleId,
        since: connectedAt,
        carState: carState,
      ),
    },
  (SessionConnecting(:final vehicleId), TripRunning(vehicleId: final trip))
      when trip == vehicleId =>
    LiveReconnecting(vehicleId),
  (SessionConnecting(:final vehicleId), _) => LiveConnecting(vehicleId),
  (SessionIdle(), TripRunning(:final vehicleId)) => LiveReconnecting(vehicleId),
  (SessionIdle(), TripConnecting(:final vehicleIds)) => LiveSearching(
    vehicleIds,
  ),
  (SessionIdle(), TripIdle() || TripEnding()) => const NoActivity(),
};

final liveActivityProvider = Provider<LiveActivity>(
  (ref) =>
      liveActivityFrom(ref.watch(sessionProvider), ref.watch(tripProvider)),
);
