import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_state.dart';
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

/// Nothing running: connect by hand, or start a trip as if the car's
/// Bluetooth connected.
final class IdleControls extends ManualControls {
  const IdleControls();
}

ManualControls manualControlsFrom(SessionState session, TripState trip) =>
    switch ((session, trip)) {
      (_, TripIdle()) => switch (session) {
        SessionConnected(:final busy) => SessionControls(canRead: !busy),
        SessionConnecting() => const WaitingControls(),
        SessionIdle() => const IdleControls(),
      },
      (_, TripEnding()) => const TripControls(canStop: false),
      (_, TripConnecting() || TripRunning()) => const TripControls(
        canStop: true,
      ),
    };

final manualControlsProvider = Provider<ManualControls>(
  (ref) =>
      manualControlsFrom(ref.watch(sessionProvider), ref.watch(tripProvider)),
);
