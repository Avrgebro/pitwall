import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/state/manual_controls.dart';
import 'package:pitwall/state/session_state.dart';
import 'package:pitwall/state/trip_state.dart';

void main() {
  final now = DateTime(2026, 11, 2);
  final connected = SessionConnected(vehicleId: 'tucson', connectedAt: now);

  test('idle offers connecting and simulating a trip', () {
    expect(
      manualControlsFrom(const SessionIdle(), const TripIdle()),
      isA<IdleControls>(),
    );
  });

  test('connected by hand reads unless the adapter is busy', () {
    expect(
      manualControlsFrom(connected, const TripIdle()),
      isA<SessionControls>().having((c) => c.canRead, 'can read', isTrue),
    );
    expect(
      manualControlsFrom(connected.copyWith(busy: true), const TripIdle()),
      isA<SessionControls>().having((c) => c.canRead, 'can read', isFalse),
    );
  });

  test('a trip leaves only stopping it, until it ends', () {
    final running = TripRunning(vehicleId: 'tucson', since: now);
    expect(
      manualControlsFrom(connected, running),
      isA<TripControls>().having((c) => c.canStop, 'can stop', isTrue),
    );
    expect(
      manualControlsFrom(const SessionIdle(), const TripEnding()),
      isA<TripControls>().having((c) => c.canStop, 'can stop', isFalse),
    );
  });

  test('while connecting, there\'s nothing to do', () {
    expect(
      manualControlsFrom(const SessionConnecting('tucson'), const TripIdle()),
      isA<WaitingControls>(),
    );
  });
}
