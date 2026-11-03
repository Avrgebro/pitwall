import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/session/car_state.dart';
import 'package:pitwall/state/live_activity_state.dart';
import 'package:pitwall/state/session_state.dart';
import 'package:pitwall/state/trip_state.dart';

void main() {
  final now = DateTime(2026, 11, 2, 10);
  final trip = TripRunning(
    vehicleId: 'tucson',
    since: now.subtract(const Duration(minutes: 24)),
  );

  test('nothing live', () {
    expect(
      liveActivityFrom(const SessionIdle(), const TripIdle()),
      isA<NoActivity>(),
    );
  });

  test('a manual connection runs from when it was made', () {
    final live = liveActivityFrom(
      SessionConnected(vehicleId: 'tucson', connectedAt: now),
      const TripIdle(),
    );

    expect(
      live,
      isA<LiveConnected>()
          .having((l) => l.since, 'since', now)
          .having((l) => l.inTrip, 'in a trip', isFalse),
    );
  });

  test('a reconnect mid-trip keeps the trip\'s start', () {
    final live = liveActivityFrom(
      SessionConnected(
        vehicleId: 'tucson',
        connectedAt: now.subtract(const Duration(minutes: 1)),
        carState: CarState.engineRunning,
      ),
      trip,
    );

    expect(
      live,
      isA<LiveConnected>()
          .having((l) => l.since, 'since', trip.since)
          .having((l) => l.inTrip, 'in a trip', isTrue),
    );
  });

  test('between connections, a running trip is reconnecting', () {
    expect(
      liveActivityFrom(const SessionIdle(), trip),
      isA<LiveReconnecting>().having((l) => l.vehicleId, 'vehicle', 'tucson'),
    );
    expect(
      liveActivityFrom(const SessionConnecting('tucson'), trip),
      isA<LiveReconnecting>(),
    );
  });

  test('a first connection is connecting', () {
    expect(
      liveActivityFrom(
        const SessionConnecting('tucson'),
        const TripConnecting(),
      ),
      isA<LiveConnecting>(),
    );
  });

  test('another vehicle\'s activity is none for this one', () {
    expect(
      liveActivityFrom(const SessionIdle(), trip).forVehicle('mazda'),
      isA<NoActivity>(),
    );
  });

  test('a trip between attempts is looking, for the vehicles it\'s for', () {
    final live = liveActivityFrom(
      const SessionIdle(),
      const TripConnecting(vehicleIds: {'tucson'}),
    );

    expect(live, isA<LiveSearching>());
    expect(live.forVehicle('tucson'), isA<LiveSearching>());
    expect(live.forVehicle('mazda'), isA<NoActivity>());
  });
}
