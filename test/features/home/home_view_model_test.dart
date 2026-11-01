import 'package:flutter_test/flutter_test.dart';
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
  const settings = AppSettings(headUnitAddress: 'AA:BB:CC:DD:EE:FF');
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

  HomeViewModel build({
    SessionState session = const SessionState(),
    DeliveryStatus delivery = const DeliveryStatus(),
  }) => HomeViewModel.build(
    vehicle: vehicle,
    settings: settings,
    session: session,
    delivery: delivery,
    options: options,
    now: now,
  );

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
    expect(
      model.hero.subtitle,
      'Starts on its own when the car\'s Bluetooth connects',
    );
    expect(model.hero.stats.map((s) => s.value), [
      'Not in range',
      'Off',
      'Ended 2 h ago',
    ]);
    expect(model.delivery.message, 'Every reading from the last trip arrived');
    expect(model.values!.meta, 'Updated 2 h ago');
  });

  test('1c no signal: readings queued, nothing to do', () {
    final model = build(
      session: driving,
      delivery: DeliveryStatus(
        queued: 3,
        lastSuccess: now.subtract(const Duration(minutes: 3)),
        lastError: const DeliveryError(DeliveryErrorKind.unreachable),
        latest: reading(delivered: false),
      ),
    );

    expect(model.hero.subtitle, 'Reading the car every minute');
    expect(model.delivery.kind, DeliveryCardKind.queued);
    expect(model.delivery.title, 'No signal, 3 readings queued');
    expect(model.delivery.isProblem, isTrue);
    expect(model.delivery.canOpenSettings, isFalse);
    expect(model.delivery.stats.map((s) => s.value), [
      '3 min ago',
      'None',
      '3',
    ]);
    expect(model.values!.title, 'Latest readings');
    expect(model.values!.meta, 'Read 40 s ago · not sent yet');
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
    expect(model.delivery.canOpenSettings, isTrue);
    expect(model.delivery.canRetry, isTrue);
    expect(model.delivery.stats.map((s) => s.value), ['yesterday', '12', '12']);
    expect(model.values!.meta, 'Read 40 s ago · not delivered');
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
}
