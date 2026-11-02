import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/readings/last_values.dart';
import 'package:pitwall/core/readings/readings.dart';
import 'package:pitwall/core/session/car_state.dart';
import 'package:pitwall/core/settings/settings.dart';
import 'package:pitwall/core/vehicles/vehicle.dart';
import 'package:pitwall/core/webhook/delivery_status.dart';
import 'package:pitwall/features/home/home_view_model.dart';
import 'package:pitwall/state/session_state.dart';

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
  final options = valueOptions(null, null);
  final driving = SessionState(
    phase: SessionPhase.connected,
    vehicleId: 'tucson',
    connectedAt: now.subtract(const Duration(minutes: 24)),
    carState: CarState.engineRunning,
  );
  Reading reading({required bool delivered, DateTime? at}) => Reading(
    device: 'tucson',
    timestamp: at ?? now.subtract(const Duration(seconds: 40)),
    values: const {
      'fuel_level_pct': 46.27,
      'battery_v': 13.6,
      'coolant_temp_c': 89,
      'speed_kmh': 52,
      'odometer_km': 33999.7,
    },
    delivered: delivered,
  );

  /// Without [lastValues], this car's last values are those of the
  /// delivery's latest reading, when it's this car's.
  HomeViewModel build({
    SessionState session = const SessionState(),
    DeliveryStatus delivery = const DeliveryStatus(),
    bool hasWebhook = true,
    Map<String, LastValue>? lastValues,
  }) {
    final latest = delivery.latest;
    return HomeViewModel.build(
      vehicle: vehicle,
      settings: settings,
      session: session,
      delivery: delivery,
      hasWebhook: hasWebhook,
      options: options,
      lastValues:
          lastValues ??
          {
            if (latest != null && latest.device == vehicle.deviceId)
              for (final MapEntry(:key, :value) in latest.values.entries)
                key: LastValue(value, latest.timestamp),
          },
      now: now,
    );
  }

  test('1a driving, all healthy', () {
    final model = build(
      session: driving,
      delivery: DeliveryStatus(
        lastSuccess: now.subtract(const Duration(seconds: 40)),
        latest: reading(delivered: true),
      ),
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
        lastSuccess: now.subtract(const Duration(hours: 2)),
        latest: reading(
          delivered: true,
          at: now.subtract(const Duration(hours: 2)),
        ),
      ),
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
      delivery: DeliveryStatus(
        latest: Reading(
          device: 'mazda',
          timestamp: now.subtract(const Duration(minutes: 5)),
          values: const {'rpm': 800},
          delivered: true,
        ),
      ),
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
      session: driving,
      delivery: DeliveryStatus(
        queued: 3,
        failedAttempts: 4,
        lastSuccess: now.subtract(const Duration(minutes: 3)),
        lastError: const DeliveryError(DeliveryErrorKind.unreachable),
        latest: reading(delivered: false),
      ),
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
      session: driving,
      delivery: DeliveryStatus(
        queued: 12,
        failedAttempts: 12,
        lastSuccess: now.subtract(const Duration(days: 1)),
        lastError: const DeliveryError(
          DeliveryErrorKind.refused,
          statusCode: 401,
        ),
        latest: reading(delivered: false),
      ),
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
    final model = build(
      delivery: DeliveryStatus(
        latest: Reading(
          device: 'work-van',
          timestamp: now,
          values: const {'rpm': 800},
          delivered: true,
        ),
      ),
    );

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
}
