import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pitwall/core/bluetooth/bluetooth_gateway.dart';
import 'package:pitwall/core/platform/permission_gateway.dart';
import 'package:pitwall/core/platform/trip_service_gateway.dart';
import 'package:pitwall/core/settings/settings.dart';
import 'package:pitwall/core/vehicles/vehicle.dart';
import 'package:pitwall/core/webhook/webhook_auth.dart';
import 'package:pitwall/core/webhook/webhook_sender.dart';
import 'package:pitwall/state/infrastructure.dart';
import 'package:pitwall/state/trip_state.dart';

import '../core/obd/fake_transport.dart';
import '../core/settings/fake_settings_store.dart';
import '../core/webhook/fake_delivery_storage.dart';
import '../helpers/fakes.dart';

/// An adapter that answers like a car with the ignition on, or like one
/// that's off.
class _Adapter extends FakeTransport implements ClosableTransport {
  _Adapter({bool carOn = true})
    : super({
        'ATZ': 'ELM327 v2.1',
        'ATE0': 'OK',
        'ATL0': 'OK',
        'ATS0': 'OK',
        'ATH0': 'OK',
        'ATSP0': 'OK',
        '0100': carOn ? '410000000000' : 'SEARCHING...\rUNABLE TO CONNECT',
        'ATRV': '13.6V',
      });

  @override
  Future<void> close() async {}
}

const _tucson = Vehicle(
  id: 'tucson',
  name: 'Hyundai Tucson',
  adapterAddress: '00:1D:A5:68:98:8B',
  adapterName: 'vLinker MC+',
);

const _fast = TripTiming(
  retryDelay: Duration(milliseconds: 5),
  connectWindow: Duration(milliseconds: 40),
  carOffWindow: Duration(milliseconds: 40),
  finalDeliveryWait: Duration(seconds: 1),
);

void main() {
  late FakeTripServiceGateway service;
  late List<Map<String, Object?>> received;

  ProviderContainer container({
    ClosableTransport? Function(String)? adapter,
    List<Vehicle> vehicles = const [_tucson],
    bool pendingRequest = false,
    FakePermissionGateway? permissions,
  }) {
    service = FakeTripServiceGateway(pendingRequest: pendingRequest);
    received = [];
    final store = FakeSettingsStore(
      settings: AppSettings(
        vehicles: vehicles,
        interval: const Duration(milliseconds: 10),
        headUnitAddress: 'AA:BB:CC:DD:EE:FF',
        setupDone: true,
      ),
    )..webhookUrl = 'https://example.com/api/webhook/x';
    final sender = WebhookSender(
      storage: FakeDeliveryStorage(),
      webhookTarget: () async =>
          const WebhookTarget('https://example.com/api/webhook/x'),
      client: MockClient((request) async {
        received.add(jsonDecode(request.body) as Map<String, Object?>);
        return http.Response('', 200);
      }),
    );
    final c = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(store),
        webhookSenderProvider.overrideWithValue(sender),
        permissionGatewayProvider.overrideWithValue(
          permissions ?? FakePermissionGateway(),
        ),
        bluetoothGatewayProvider.overrideWithValue(
          FakeBluetoothGateway(adapter: adapter),
        ),
        tripServiceGatewayProvider.overrideWithValue(service),
        tripTimingProvider.overrideWithValue(_fast),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Waits until the trip is back to idle.
  Future<TripState> ended(ProviderContainer c) async {
    for (var i = 0; i < 200; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final trip = c.read(tripProvider);
      if (trip.phase == TripPhase.idle && trip.lastEnd != null) return trip;
    }
    fail('The trip did not end');
  }

  test('tells Android which head unit starts a trip', () async {
    final c = container();
    c.read(tripProvider);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(service.headUnitAddress, 'AA:BB:CC:DD:EE:FF');
  });

  test('a trip reads, sends, and closes with connected: false', () async {
    final c = container(adapter: (_) => _Adapter());
    c.read(tripProvider);

    service.send(TripCommand.start);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(c.read(tripProvider).phase, TripPhase.running);

    service.send(TripCommand.stop);
    final trip = await ended(c);

    expect(trip.lastEnd, TripEnd.stopped);
    expect(received.where((p) => p['connected'] == true), isNotEmpty);
    expect(received.first['device'], 'hyundai-tucson');
    expect(received.first['values'], {'battery_v': 13.6});
    expect(received.last['connected'], isFalse);
    expect(received.last['values'], isEmpty);
    expect(service.calls, contains('stopService'));
    expect(service.notifications.first, 'Connecting to vLinker MC+…');
    expect(service.notifications, contains('Reading Hyundai Tucson every 0 s'));
  });

  test('a request made before Dart was ready still starts a trip', () async {
    final c = container(adapter: (_) => _Adapter(), pendingRequest: true);
    c.read(tripProvider);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(c.read(tripProvider).phase, TripPhase.running);
    c.read(tripProvider.notifier).stop();
    await ended(c);
  });

  test('an unreachable adapter ends the trip without sending', () async {
    final c = container(adapter: (_) => null);
    c.read(tripProvider);

    service.send(TripCommand.start);
    final trip = await ended(c);

    expect(trip.lastEnd, TripEnd.adapterNotFound);
    expect(received, isEmpty);
    expect(service.calls, contains('stopService'));
  });

  test('a car that stays off ends the trip', () async {
    final c = container(adapter: (_) => _Adapter(carOn: false));
    c.read(tripProvider);

    service.send(TripCommand.start);
    final trip = await ended(c);

    expect(trip.lastEnd, TripEnd.carOff);
    expect(
      service.notifications,
      contains('Waiting for Hyundai Tucson to answer'),
    );
    // The trip reached the adapter, so its end is still marked.
    expect(received.single['connected'], isFalse);
  });

  test('without a vehicle there is nothing to start', () async {
    final c = container(vehicles: const []);
    c.read(tripProvider);

    service.send(TripCommand.start);
    final trip = await ended(c);

    expect(trip.lastEnd, TripEnd.noVehicle);
    expect(service.calls, contains('stopService'));
  });

  test(
    'a missing Bluetooth permission ends the trip without prompting',
    () async {
      final permissions = FakePermissionGateway({
        AppPermission.bluetooth: false,
      });
      final c = container(adapter: (_) => _Adapter(), permissions: permissions);
      c.read(tripProvider);

      service.send(TripCommand.start);
      final trip = await ended(c);

      expect(trip.lastEnd, TripEnd.permissionMissing);
      // Not asked: there's no screen during a trip.
      expect(permissions.granted[AppPermission.bluetooth], isFalse);
    },
  );
}
