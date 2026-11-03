import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/readings/last_values.dart';
import 'package:pitwall/core/readings/readings.dart';
import 'package:pitwall/core/session/car_state.dart';
import 'package:pitwall/core/settings/settings.dart';
import 'package:pitwall/core/vehicles/vehicle.dart';
import 'package:pitwall/core/webhook/delivery_status.dart';
import 'package:pitwall/features/home/home_view_model.dart';
import 'package:pitwall/state/live_activity_state.dart';

/// The four Home states from the mockups (1a–1d), plus first use.
void main() {
  final now = DateTime(2026, 10, 31, 10, 24);
  final vehicle = Vehicle(
    id: 'tucson',
    name: 'Tucson',
    adapterName: 'vLinker MC+',
    lastSeen: DateTime(2026, 10, 31, 8, 24),
  );
  const settings = AppSettings();
  final driving = LiveConnected(
    vehicleId: 'tucson',
    since: now.subtract(const Duration(minutes: 24)),
    carState: CarState.engineRunning,
  );

  /// This car's last values, all from reading 1, read [at].
  Map<String, LastValue> lastReading({DateTime? at}) => {
    for (final MapEntry(:key, :value) in const {
      'fuel_level_pct': 46.27,
      'battery_v': 13.6,
      'coolant_temp_c': 89,
      'speed_kmh': 52,
      'odometer_km': 33999.7,
    }.entries)
      key: LastValue(
        value,
        at ?? now.subtract(const Duration(seconds: 40)),
        seq: 1,
      ),
  };

  HomeViewModel build({
    LiveActivity activity = const NoActivity(),
    DeliveryStatus delivery = const DeliveryStatus(),
    bool hasWebhook = true,
    Map<String, LastValue> lastValues = const {},
  }) => HomeViewModel.build(
    vehicle: vehicle,
    settings: settings,
    activity: activity,
    delivery: delivery,
    hasWebhook: hasWebhook,
    values: VehicleValues.of(vehicle, null),
    lastValues: lastValues,
    now: now,
  );

  test('1a driving, all healthy', () {
    final model = build(
      activity: driving,
      delivery: DeliveryStatus(
        outcome: DeliveryOutcome(
          lastSuccess: now.subtract(const Duration(seconds: 40)),
        ),
        deliveredThrough: 1,
      ),
      lastValues: lastReading(),
    );

    expect(model.hero.state, HeroState.running);
    expect(model.hero.subtitle, 'Sending a reading every minute');
    expect(model.hero.stats.map((s) => s.value), [
      'Connected',
      'Engine running',
      '24 min',
    ]);
    expect(model.delivery.kind, DeliveryCardKind.healthy);
    expect(model.delivery.title, 'Delivery healthy');
    expect(model.delivery.isProblem, isFalse);
    expect(model.values!.title, 'Last values sent');
    expect(model.values!.meta, 'Updated 40 s ago');
    expect(model.values!.tiles.map((t) => t.label), [
      'Fuel',
      'Battery',
      'Coolant',
      'Speed',
      'Odometer',
    ]);
    expect(model.values!.tiles.last.value, '34,000');
  });

  test('1b parked, waiting for the car', () {
    final model = build(
      delivery: DeliveryStatus(
        outcome: DeliveryOutcome(
          lastSuccess: now.subtract(const Duration(hours: 2)),
        ),
        deliveredThrough: 1,
      ),
      lastValues: lastReading(at: now.subtract(const Duration(hours: 2))),
    );

    expect(model.hero.state, HeroState.waiting);
    expect(model.hero.subtitle, isNull);
    expect(model.hero.stats.map((s) => (s.label, s.value)), [
      ('Adapter', 'Not connected'),
      ('Last connected', '2 h ago'),
      ('Last reading', '2 h ago'),
    ]);
    expect(model.delivery.message, isNull);
    expect(model.values!.meta, 'Updated 2 h ago');
  });

  test('another car\'s newer reading doesn\'t hide this car\'s values', () {
    final model = build(
      delivery: DeliveryStatus(),
      lastValues: {
        'odometer_km': LastValue(
          33999.7,
          now.subtract(const Duration(hours: 1)),
        ),
      },
    );

    expect(model.hero.stats.last, (
      kind: HeroStatKind.lastReading,
      label: 'Last reading',
      value: '1 h ago',
    ));
    expect(model.values!.title, 'Last values');
    expect(model.values!.meta, 'Read 1 h ago');
    expect(model.values!.tiles.single.value, '34,000');
  });

  test('values the car stopped reporting keep their own time', () {
    // Switching off: the last reading had only the battery voltage.
    final model = build(
      lastValues: {
        'battery_v': LastValue(12.4, now.subtract(const Duration(minutes: 2))),
        'odometer_km': LastValue(
          33999.7,
          now.subtract(const Duration(minutes: 6)),
        ),
        'coolant_temp_c': LastValue(
          89,
          now.subtract(const Duration(minutes: 2, seconds: 30)),
        ),
      },
    );

    expect(model.values!.meta, 'Read 2 min ago');
    final notes = {for (final t in model.values!.tiles) t.label: t.note};
    expect(notes['Battery'], isNull);
    // Within a minute of the newest: no need to say.
    expect(notes['Coolant'], isNull);
    expect(notes['Odometer'], 'Read 6 min ago');
  });

  test('values no longer sent aren\'t shown', () {
    final model = build(
      lastValues: {
        'battery_v': LastValue(12.4, now),
        'tucson_fli_vol': LastValue(47.5, now),
      },
    );

    // tucson_fli_vol is a profile key, off unless chosen.
    expect(model.values!.tiles.map((t) => t.label), ['Battery']);
  });

  test('1c no signal: readings queued, nothing to do', () {
    final model = build(
      activity: driving,
      delivery: DeliveryStatus(
        queued: 3,
        outcome: DeliveryOutcome(
          failedAttempts: 4,
          lastSuccess: now.subtract(const Duration(minutes: 3)),
          lastError: const Unreachable(),
        ),
      ),
      lastValues: lastReading(),
    );

    expect(model.hero.subtitle, 'Reading the car every minute');
    expect(model.delivery.kind, DeliveryCardKind.queued);
    expect(model.delivery.title, 'No signal, 3 readings queued');
    expect(model.delivery.isProblem, isTrue);
    expect(model.delivery.actions, isEmpty);
    // Failed attempts show even while they're retried on their own.
    expect(model.delivery.stats.map((s) => s.value), ['3 min ago', '4', '3']);
    expect(model.values!.title, 'Latest readings');
    expect(model.values!.meta, 'Read 40 s ago, not sent yet');
  });

  test('1d webhook refusing readings: needs the user', () {
    final model = build(
      activity: driving,
      delivery: DeliveryStatus(
        queued: 12,
        outcome: DeliveryOutcome(
          failedAttempts: 12,
          lastSuccess: now.subtract(const Duration(days: 1)),
          lastError: const Rejected(401),
        ),
      ),
      lastValues: lastReading(),
    );

    expect(model.delivery.kind, DeliveryCardKind.failing);
    expect(model.delivery.title, 'The webhook is refusing readings');
    expect(model.delivery.message, contains('(HTTP 401)'));
    expect(model.delivery.actions, {
      DeliveryAction.openSettings,
      DeliveryAction.retry,
    });
    expect(model.delivery.stats.map((s) => s.value), ['yesterday', '12', '12']);
    expect(model.values!.meta, 'Read 40 s ago, not delivered');
  });

  test('first use: nothing sent yet, no values', () {
    final model = build();

    expect(model.delivery.title, 'Ready to send');
    expect(model.values, isNull);
  });

  test('readings from another vehicle are not shown', () {
    final model = build(delivery: DeliveryStatus());

    expect(model.values, isNull);
  });

  test('without a webhook the delivery card asks for one', () {
    final model = build(
      hasWebhook: false,
      delivery: const DeliveryStatus(queued: 2),
    );

    expect(model.delivery.kind, DeliveryCardKind.noWebhook);
    expect(model.delivery.title, 'No webhook yet');
    expect(model.delivery.actions, {DeliveryAction.setWebhook});
    expect(model.delivery.isProblem, isTrue);
    expect(model.delivery.stats.single.value, '2');
  });

  test('a reconnecting trip says so', () {
    final model = build(activity: const LiveReconnecting('tucson'));

    expect(model.hero.state, HeroState.connecting);
    expect(model.hero.subtitle, 'Reconnecting to vLinker MC+…');
  });

  test('a trip between connection attempts is still looking', () {
    final model = build(activity: const LiveSearching({'tucson'}));

    expect(model.hero.state, HeroState.connecting);
    expect(model.hero.subtitle, 'Looking for vLinker MC+…');
  });

  test('another car\'s activity doesn\'t show on this one', () {
    final model = build(
      activity: LiveConnected(
        vehicleId: 'mazda',
        since: now,
        carState: CarState.engineRunning,
      ),
    );

    expect(model.hero.state, HeroState.waiting);
  });

  test('delivered goes by the reading\'s number, not the vehicle\'s name', () {
    // The vehicle was renamed since; its values still know their reading.
    final model = build(
      delivery: DeliveryStatus(
        outcome: DeliveryOutcome(lastSuccess: now),
        deliveredThrough: 1,
      ),
      lastValues: lastReading(),
    );
    expect(model.values!.title, 'Last values sent');

    final waiting = build(
      delivery: DeliveryStatus(
        outcome: DeliveryOutcome(lastSuccess: now),
        deliveredThrough: 0,
      ),
      lastValues: lastReading(),
    );
    expect(waiting.values!.title, 'Latest readings');
  });

  test('a value no longer sent says nothing about the last reading', () {
    final model = build(
      lastValues: {
        'battery_v': LastValue(12.4, now.subtract(const Duration(hours: 1))),
        // Fresher, but a profile value that's off.
        'tucson_fli_vol': LastValue(47.5, now),
      },
    );

    expect(model.hero.stats.last.value, '1 h ago');
  });
}
