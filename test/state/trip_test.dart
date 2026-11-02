import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pitwall/core/bluetooth/bluetooth_gateway.dart';
import 'package:pitwall/core/platform/permission_gateway.dart';
import 'package:pitwall/core/settings/settings.dart';
import 'package:pitwall/core/trips/trip_target.dart';
import 'package:pitwall/core/vehicles/vehicle.dart';
import 'package:pitwall/core/webhook/webhook_auth.dart';
import 'package:pitwall/core/webhook/webhook_sender.dart';
import 'package:pitwall/state/infrastructure.dart';
import 'package:pitwall/state/settings_state.dart';
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

const _tucsonStereo = 'AA:BB:CC:DD:EE:FF';
const _mazdaStereo = '11:22:33:44:55:66';

const _tucson = Vehicle(
  id: 'tucson',
  name: 'Hyundai Tucson',
  adapterAddress: '00:1D:A5:68:98:8B',
  adapterName: 'vLinker MC+',
  headUnitAddress: _tucsonStereo,
  headUnitName: 'TUCSON BT',
);

const _mazda = Vehicle(
  id: 'mazda',
  name: 'Mazda',
  adapterAddress: '00:00:00:00:00:02',
  adapterName: 'OBDII',
  headUnitAddress: _mazdaStereo,
  headUnitName: 'MAZDA',
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
  late FakeLastValuesStorage lastValues;

  ProviderContainer container({
    ClosableTransport? Function(String)? adapter,
    List<Vehicle> vehicles = const [_tucson],
    TripTarget? pendingRequest,
    FakePermissionGateway? permissions,
    FakeBluetoothGateway? bluetooth,
  }) {
    service = FakeTripServiceGateway(pendingRequest: pendingRequest);
    received = [];
    lastValues = FakeLastValuesStorage();
    final store = FakeSettingsStore(
      settings: AppSettings(
        vehicles: vehicles,
        interval: const Duration(milliseconds: 10),
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
        lastValuesStorageProvider.overrideWithValue(lastValues),
        permissionGatewayProvider.overrideWithValue(
          permissions ?? FakePermissionGateway(),
        ),
        bluetoothGatewayProvider.overrideWithValue(
          bluetooth ?? FakeBluetoothGateway(adapter: adapter),
        ),
        tripServiceGatewayProvider.overrideWithValue(service),
        tripTimingProvider.overrideWithValue(_fast),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Waits until the trip is back to idle.
  /// Waits until [condition] holds.
  Future<void> until(bool Function() condition, String what) async {
    for (var i = 0; i < 400; i++) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('Timed out waiting for $what');
  }

  /// Waits until the trip is running, connected to a vehicle.
  Future<TripState> running(ProviderContainer c) async {
    for (var i = 0; i < 200; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final trip = c.read(tripProvider);
      if (trip.phase == TripPhase.running) return trip;
    }
    fail('The trip did not start');
  }

  Future<TripState> ended(ProviderContainer c) async {
    for (var i = 0; i < 200; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final trip = c.read(tripProvider);
      if (trip.phase == TripPhase.idle && trip.lastEnd != null) return trip;
    }
    fail('The trip did not end');
  }

  test('tells Android which head units start a trip', () async {
    final c = container(vehicles: const [_tucson, _mazda]);
    c.read(tripProvider);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(service.headUnitAddresses, {_tucsonStereo, _mazdaStereo});
  });

  test('a trip reads, sends, and closes with connected: false', () async {
    final c = container(adapter: (_) => _Adapter());
    c.read(tripProvider);

    service.send(const HeadUnitTarget(_tucsonStereo));
    await running(c);

    c.read(tripProvider.notifier).stop();
    final trip = await ended(c);

    expect(trip.lastEnd, TripEnd.stopped);
    expect(received.where((p) => p['connected'] == true), isNotEmpty);
    expect(received.first['device'], 'hyundai-tucson');
    expect(received.first['values'], {'battery_v': 13.6});
    expect(received.first['engine'], 'running');
    expect(received.last['connected'], isFalse);
    expect(received.last['values'], isEmpty);
    expect(service.calls, contains('stopService'));
    expect(service.notifications.first, 'Connecting to vLinker MC+…');
    expect(
      service.notifications,
      contains('Reading Hyundai Tucson every 0 seconds'),
    );
    // What was read is kept for Home, by vehicle.
    expect(lastValues.saved.of(_tucson.id)['battery_v']?.value, 13.6);
  });

  test('a request made before Dart was ready still starts a trip', () async {
    final c = container(
      adapter: (_) => _Adapter(),
      pendingRequest: const HeadUnitTarget(_tucsonStereo),
    );
    c.read(tripProvider);
    await running(c);
    c.read(tripProvider.notifier).stop();
    await ended(c);
  });

  test('an unreachable adapter ends the trip without sending', () async {
    final c = container(adapter: (_) => null);
    c.read(tripProvider);

    service.send(const HeadUnitTarget(_tucsonStereo));
    final trip = await ended(c);

    expect(trip.lastEnd, TripEnd.adapterNotFound);
    expect(received, isEmpty);
    expect(service.calls, contains('stopService'));
  });

  test('a car that stays off ends the trip', () async {
    final c = container(adapter: (_) => _Adapter(carOn: false));
    c.read(tripProvider);

    service.send(const HeadUnitTarget(_tucsonStereo));
    final trip = await ended(c);

    expect(trip.lastEnd, TripEnd.carOff);
    expect(
      service.notifications,
      contains('Waiting for Hyundai Tucson to answer'),
    );
    // Nothing was sent, so there's nothing to close: a stereo waking with
    // the car parked leaves no trace at the receiver.
    expect(received, isEmpty);
  });

  test('without a vehicle there is nothing to start', () async {
    final c = container(vehicles: const []);
    c.read(tripProvider);

    service.send(const HeadUnitTarget(_tucsonStereo));
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

      service.send(const HeadUnitTarget(_tucsonStereo));
      final trip = await ended(c);

      expect(trip.lastEnd, TripEnd.permissionMissing);
      // Not asked: there's no screen during a trip.
      expect(permissions.granted[AppPermission.bluetooth], isFalse);
    },
  );

  test('a head unit starts a trip with its own vehicle only', () async {
    final bluetooth = FakeBluetoothGateway(adapter: (_) => _Adapter());
    final c = container(
      vehicles: [
        _tucson.copyWith(lastSeen: DateTime(2026, 11, 1)),
        _mazda,
      ],
      bluetooth: bluetooth,
    );
    c.read(tripProvider);

    service.send(const HeadUnitTarget(_mazdaStereo));
    expect((await running(c)).vehicleId, 'mazda');
    expect(bluetooth.connected.toSet(), {_mazda.adapterAddress});
    c.read(tripProvider.notifier).stop();
    await ended(c);
  });

  test('a head unit connecting during a trip changes nothing', () async {
    final c = container(
      vehicles: const [_tucson, _mazda],
      adapter: (_) => _Adapter(),
    );
    c.read(tripProvider);

    service.send(const HeadUnitTarget(_tucsonStereo));
    await running(c);
    service.send(const HeadUnitTarget(_mazdaStereo));
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(c.read(tripProvider).vehicleId, 'tucson');
    c.read(tripProvider.notifier).stop();
    await ended(c);
  });

  test('a head unit no vehicle uses starts nothing', () async {
    final c = container(adapter: (_) => _Adapter());
    c.read(tripProvider);

    service.send(const HeadUnitTarget('99:99:99:99:99:99'));
    expect((await ended(c)).lastEnd, TripEnd.noVehicle);
  });

  test('a trip started from the app tries every vehicle', () async {
    final bluetooth = FakeBluetoothGateway(
      adapter: (address) =>
          address == _mazda.adapterAddress ? _Adapter() : null,
    );
    final c = container(
      vehicles: [
        _tucson.copyWith(lastSeen: DateTime(2026, 11, 1)),
        _mazda,
      ],
      bluetooth: bluetooth,
    );
    c.read(tripProvider);

    await c.read(tripProvider.notifier).startManually();
    expect((await running(c)).vehicleId, 'mazda');
    // The most recently seen car is tried first.
    expect(bluetooth.connected.first, _tucson.adapterAddress);
    c.read(tripProvider.notifier).stop();
    await ended(c);
  });

  test('Android hears when a vehicle\'s head unit changes', () async {
    final c = container();
    c.read(tripProvider);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await c
        .read(appSettingsProvider.notifier)
        .setHeadUnit('tucson', address: '77:77:77:77:77:77', name: 'NEW');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(service.headUnitAddresses, {'77:77:77:77:77:77'});
  });

  test('an adapter that drops and stays away ends the trip', () async {
    final adapters = <_Adapter>[];
    final c = container(
      // The first connection works; afterwards the adapter is out of reach.
      adapter: (_) {
        if (adapters.isNotEmpty) return null;
        final adapter = _Adapter();
        adapters.add(adapter);
        return adapter;
      },
    );
    c.read(tripProvider);

    service.send(const HeadUnitTarget(_tucsonStereo));
    await running(c);

    await adapters.single.disconnect();
    final trip = await ended(c);

    expect(trip.lastEnd, TripEnd.adapterLost);
    expect(received.last['connected'], isFalse);
  });

  test(
    'a car switched off after readings ends the trip, marked once',
    () async {
      late _Adapter adapter;
      final c = container(adapter: (_) => adapter = _Adapter());
      c.read(tripProvider);
      service.send(const HeadUnitTarget(_tucsonStereo));
      await running(c);
      await until(() => received.isNotEmpty, 'a reading');

      // The car stops answering; the adapter itself still reads the battery.
      adapter.replies['0100'] = 'SEARCHING...\rUNABLE TO CONNECT';
      adapter.replies['ATRV'] = '12.4V';
      final trip = await ended(c);

      expect(trip.lastEnd, TripEnd.carOff);
      expect(received.last['connected'], isFalse);
      expect(received.where((p) => p['connected'] == false), hasLength(1));
    },
  );

  test('a trip started from the app for one vehicle goes to it only', () async {
    final bluetooth = FakeBluetoothGateway(adapter: (_) => _Adapter());
    final c = container(
      vehicles: [
        _tucson.copyWith(lastSeen: DateTime(2026, 11, 1)),
        _mazda,
      ],
      bluetooth: bluetooth,
    );
    c.read(tripProvider);

    await c.read(tripProvider.notifier).startManually(vehicleId: 'mazda');

    expect((await running(c)).vehicleId, 'mazda');
    expect(bluetooth.connected.toSet(), {_mazda.adapterAddress});
    c.read(tripProvider.notifier).stop();
    await ended(c);
  });
}
