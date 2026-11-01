import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/bluetooth/bluetooth_gateway.dart';
import '../core/logging/adapter_log.dart';
import '../core/platform/file_gateway.dart';
import '../core/platform/permission_gateway.dart';
import '../core/platform/trip_service_gateway.dart';
import '../core/settings/settings_store.dart';
import '../core/webhook/delivery_status.dart';
import '../core/webhook/delivery_storage.dart';
import '../core/webhook/webhook_sender.dart';

/// Services from the core layer. Tests override these with fakes.

final settingsStoreProvider = Provider<SettingsStore>((ref) => SettingsStore());

final bluetoothGatewayProvider = Provider<BluetoothGateway>(
  (ref) => const ClassicBluetoothGateway(),
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

final adapterLogProvider = Provider<AdapterLog>((ref) {
  final log = AdapterLog();
  ref.onDispose(log.dispose);
  return log;
});

/// The one sender for the whole app. `main` calls `init()` before the UI
/// starts, so queued readings resume right away.
final webhookSenderProvider = Provider<WebhookSender>((ref) {
  final log = ref.watch(adapterLogProvider);
  final sender = WebhookSender(
    storage: ref.watch(deliveryStorageProvider),
    webhookTarget: ref.watch(settingsStoreProvider).loadWebhookTarget,
    onAttempt: (attempt) => _logAttempt(log, attempt),
  );
  ref.onDispose(sender.dispose);
  return sender;
});

void _logAttempt(AdapterLog log, DeliveryAttempt attempt) {
  final target = attempt.test ? 'webhook (test)' : 'webhook';
  final elapsed = '${attempt.elapsed.inMilliseconds} ms';
  if (attempt.error case final error? when attempt.statusCode == null) {
    log.delivery('POST $target ✕ ${error.kind.name} · $elapsed', warning: true);
  } else {
    log.delivery(
      'POST $target ← ${attempt.statusCode} · $elapsed',
      warning: attempt.error != null,
    );
  }
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
