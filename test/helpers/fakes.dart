import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pitwall/core/bluetooth/bluetooth_gateway.dart';
import 'package:pitwall/core/bluetooth/classic_bluetooth.dart';

import 'dart:async';

import 'package:flutter/services.dart';

import 'package:pitwall/core/platform/permission_gateway.dart';
import 'package:pitwall/core/platform/trip_service_gateway.dart';
import 'package:pitwall/core/settings/settings.dart';
import 'package:pitwall/core/webhook/webhook_sender.dart';
import 'package:pitwall/state/infrastructure.dart';
import 'package:pitwall/state/session_state.dart';

import '../core/settings/fake_settings_store.dart';
import '../core/webhook/fake_delivery_storage.dart';

/// A fixed "now", so relative times are predictable and no timer runs.
final testNow = DateTime(2026, 10, 31, 18, 47);

class FixedNow extends NowNotifier {
  @override
  DateTime build() => testNow;
}

class FakePermissionGateway implements PermissionGateway {
  FakePermissionGateway([Map<AppPermission, bool>? granted])
    : granted = granted ?? {for (final p in AppPermission.values) p: true};

  final Map<AppPermission, bool> granted;

  @override
  Future<bool> isGranted(AppPermission permission) async =>
      granted[permission] ?? false;

  @override
  Future<bool> request(AppPermission permission) async =>
      granted[permission] = true;
}

class FakeBluetoothGateway implements BluetoothGateway {
  FakeBluetoothGateway({this.devices = const [], this.adapter});

  final List<BondedDevice> devices;

  /// Hands out a connection per attempt; null means the adapter can't be
  /// reached.
  final ClosableTransport? Function(String address)? adapter;
  int attempts = 0;

  /// The adapter addresses connected to, in order.
  final connected = <String>[];

  @override
  Future<List<BondedDevice>> bondedDevices() async => devices;

  @override
  Future<ClosableTransport> connect(String address) async {
    attempts++;
    connected.add(address);
    final transport = adapter?.call(address);
    if (transport == null) {
      throw PlatformException(code: 'connect_failed');
    }
    return transport;
  }
}

/// Records what Dart asks of the Android trip service.
class FakeTripServiceGateway implements TripServiceGateway {
  FakeTripServiceGateway({this.pendingRequest});

  StartTrip? pendingRequest;
  final calls = <String>[];
  final notifications = <String>[];
  Set<String>? headUnitAddresses;
  final _starts = StreamController<StartTrip>.broadcast();

  void send(StartTrip start) => _starts.add(start);

  @override
  Stream<StartTrip> get starts => _starts.stream;

  @override
  Future<StartTrip?> takeTripRequest() async {
    final pending = pendingRequest;
    pendingRequest = null;
    return pending;
  }

  @override
  Future<void> configure({required Set<String> headUnitAddresses}) async =>
      this.headUnitAddresses = headUnitAddresses;

  @override
  Future<void> startService() async {
    calls.add('startService');
    send(const StartTrip());
  }

  @override
  Future<void> stopService() async => calls.add('stopService');

  @override
  Future<void> updateNotification(String text) async => notifications.add(text);
}

/// A session that stays in the given state.
class FixedSession extends SessionController {
  FixedSession(this.initial);

  final SessionState initial;

  @override
  SessionState build() => initial;
}

/// Provider overrides for an app with no real phone behind it.
List<Override> testOverrides({
  AppSettings settings = const AppSettings(),
  SessionState session = const SessionState(),
  Map<AppPermission, bool>? permissions,
  FakeSettingsStore? store,
  FakeBluetoothGateway? bluetooth,
}) {
  final sender = WebhookSender(
    storage: FakeDeliveryStorage(),
    webhookTarget: () async => null,
    client: MockClient((_) async => http.Response('', 200)),
  );
  return [
    settingsStoreProvider.overrideWithValue(
      store ?? FakeSettingsStore(settings: settings),
    ),
    webhookSenderProvider.overrideWithValue(sender),
    permissionGatewayProvider.overrideWithValue(
      FakePermissionGateway(permissions),
    ),
    bluetoothGatewayProvider.overrideWithValue(
      bluetooth ?? FakeBluetoothGateway(),
    ),
    tripServiceGatewayProvider.overrideWithValue(FakeTripServiceGateway()),
    packageInfoProvider.overrideWith(
      (ref) async => PackageInfo(
        appName: 'Pitwall',
        packageName: 'io.github.avrgebro.pitwall',
        version: '0.1.0',
        buildNumber: '1',
      ),
    ),
    nowProvider.overrideWith(FixedNow.new),
    sessionProvider.overrideWith(() => FixedSession(session)),
  ];
}
