import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/bluetooth/adapter_type.dart';
import 'package:pitwall/core/vehicles/vehicle.dart';
import 'package:pitwall/state/manual_controls.dart';
import 'package:pitwall/state/session_state.dart';
import 'package:pitwall/state/trip_state.dart';

void main() {
  final now = DateTime(2026, 11, 2);
  final connected = SessionConnected(vehicleId: 'tucson', connectedAt: now);
  const tucson = Vehicle(
    id: 'tucson',
    name: 'Tucson',
    adapter: VehicleAdapter(
      address: 'A',
      name: 'vLinker',
      type: AdapterType.classic,
    ),
  );

  ManualControls controls(SessionState session, TripState trip) =>
      manualControlsFrom(session, trip, vehicle: tucson);

  test('idle offers connecting and simulating a trip', () {
    expect(
      controls(const SessionIdle(), const TripIdle()),
      isA<IdleControls>().having((c) => c.vehicle.id, 'vehicle', 'tucson'),
    );
  });

  test('idle says what stops it from starting anything', () {
    IdleBlocker? blocker(Vehicle? vehicle, {bool bluetoothOn = true}) =>
        switch (manualControlsFrom(
          const SessionIdle(),
          const TripIdle(),
          vehicle: vehicle,
          bluetoothOn: bluetoothOn,
        )) {
          BlockedControls(:final blocker) => blocker,
          _ => null,
        };

    expect(blocker(null), IdleBlocker.noVehicle);
    expect(
      blocker(const Vehicle(id: 'new', name: 'New')),
      IdleBlocker.needsAdapter,
    );
    expect(blocker(tucson, bluetoothOn: false), IdleBlocker.bluetoothOff);
    expect(blocker(tucson), isNull);
  });

  test('connected by hand reads unless the adapter is busy', () {
    expect(
      controls(connected, const TripIdle()),
      isA<SessionControls>().having((c) => c.canRead, 'can read', isTrue),
    );
    expect(
      controls(connected.copyWith(busy: true), const TripIdle()),
      isA<SessionControls>().having((c) => c.canRead, 'can read', isFalse),
    );
  });

  test('a trip leaves only stopping it, until it ends', () {
    final running = TripRunning(vehicleId: 'tucson', since: now);
    expect(
      controls(connected, running),
      isA<TripControls>().having((c) => c.canStop, 'can stop', isTrue),
    );
    expect(
      controls(const SessionIdle(), const TripEnding()),
      isA<TripControls>().having((c) => c.canStop, 'can stop', isFalse),
    );
  });

  test('while connecting, there\'s nothing to do', () {
    expect(
      controls(const SessionConnecting('tucson'), const TripIdle()),
      isA<WaitingControls>(),
    );
  });
}
