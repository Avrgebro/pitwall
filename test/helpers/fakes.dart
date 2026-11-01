import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pitwall/core/bluetooth/bluetooth_gateway.dart';
import 'package:pitwall/core/bluetooth/classic_bluetooth.dart';
import 'package:pitwall/core/platform/permission_gateway.dart';
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
  FakeBluetoothGateway([this.devices = const []]);

  final List<BondedDevice> devices;

  @override
  Future<List<BondedDevice>> bondedDevices() async => devices;

  @override
  Future<ClosableTransport> connect(String address) =>
      throw UnimplementedError('Not used in widget tests');
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
    bluetoothGatewayProvider.overrideWithValue(FakeBluetoothGateway()),
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
