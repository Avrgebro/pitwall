import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/bluetooth/android_bluetooth.dart';
import '../core/bluetooth/bluetooth_gateway.dart';
import '../core/logging/adapter_log.dart';
import '../core/platform/file_gateway.dart';
import '../core/platform/permission_gateway.dart';
import '../core/platform/share_gateway.dart';
import '../core/platform/trip_service_gateway.dart';
import '../core/readings/last_values.dart';
import '../core/settings/settings_store.dart';
import '../core/webhook/delivery_status.dart';
import '../core/webhook/delivery_storage.dart';
import '../core/webhook/webhook_sender.dart';

/// Services from the core layer. Tests override these with fakes.

final settingsStoreProvider = Provider<SettingsStore>((ref) => SettingsStore());

final bluetoothGatewayProvider = Provider<BluetoothGateway>(
  (ref) => AndroidBluetoothGateway(),
);

/// Whether Bluetooth is on, kept current.
final bluetoothOnProvider = StreamProvider<bool>(
  (ref) => ref.watch(bluetoothGatewayProvider).enabled,
);

final shareGatewayProvider = Provider<ShareGateway>(
  (ref) => const AndroidShareGateway(),
);

final permissionGatewayProvider = Provider<PermissionGateway>(
  (ref) => const PermissionHandlerGateway(),
);

final fileGatewayProvider = Provider<FileGateway>(
  (ref) => const FilePickerGateway(),
);

final tripServiceGatewayProvider = Provider<TripServiceGateway>(
  (ref) => AndroidTripServiceGateway(),
);

final deliveryStorageProvider = Provider<DeliveryStorage>(
  (ref) => FileDeliveryStorage(),
);

final lastValuesStorageProvider = Provider<LastValuesStorage>(
  (ref) => FileLastValuesStorage(),
);

final adapterLogProvider = Provider<AdapterLog>((ref) {
  // Also in Android's log, under "flutter", as "Pitwall: ...", where adb
  // reads it back.
  final log = AdapterLog(mirror: (line) => debugPrint('Pitwall: $line'));
  ref.onDispose(log.dispose);
  return log;
});

/// The one sender for the whole app. `main` calls `init()` before the UI
/// starts, so queued readings resume right away.
final webhookSenderProvider = Provider<WebhookSender>((ref) {
  final log = ref.watch(adapterLogProvider);
  final sender = WebhookSender(
    storage: ref.watch(deliveryStorageProvider),
    webhookTarget: ref.watch(settingsStoreProvider).loadWebhook,
    onAttempt: (attempt) => _logAttempt(log, attempt),
    onDropped: (reading, attempt) => log.delivery(
      'Dropped reading ${reading.seq}: the server won\'t take it',
      warning: true,
    ),
  );
  ref.onDispose(sender.dispose);
  return sender;
});

void _logAttempt(AdapterLog log, DeliveryAttempt attempt) {
  final target = attempt.test ? 'webhook (test)' : 'webhook';
  final elapsed = '${attempt.elapsed.inMilliseconds} ms';
  final result = switch (attempt.result) {
    Accepted(:final statusCode) ||
    Rejected(:final statusCode) => '← $statusCode',
    UnusableWebhook() || UnreadableWebhook() => '✕ webhook not usable',
    TimedOut() => '✕ timeout',
    Unreachable(:final failure) => '✕ unreachable (${failure.label})',
  };
  log.delivery(
    'POST $target $result, $elapsed',
    warning: attempt.result is DeliveryError,
  );
}

final packageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

/// The current time, refreshed every few seconds so "40 s ago" stays true.
final nowProvider = NotifierProvider<NowNotifier, DateTime>(NowNotifier.new);

class NowNotifier extends Notifier<DateTime> {
  static const tick = Duration(seconds: 5);

  @override
  DateTime build() {
    final timer = Timer.periodic(tick, (_) => state = DateTime.now());
    ref.onDispose(timer.cancel);
    return DateTime.now();
  }
}
