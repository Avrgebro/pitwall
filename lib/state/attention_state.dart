import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/webhook/delivery_status.dart';

import 'permissions_state.dart';
import 'settings_state.dart';
import 'webhook_state.dart';

/// Whether Settings needs the user: a delivery problem only they can fix,
/// or a missing permission.
final settingsAttentionProvider = Provider<bool>((ref) {
  final error = ref.watch(
    deliveryStatusProvider.select((status) => status.outcome.lastError),
  );
  return (error != null && error.fix != DeliveryFix.retry) ||
      ref.watch(missingPermissionsProvider) > 0;
});

/// Whether a vehicle lacks something before it works on its own.
final vehiclesAttentionProvider = Provider<bool>(
  (ref) => ref.watch(
    appSettingsProvider.select(
      (settings) =>
          settings.value?.vehicles.any((v) => v.needs.isNotEmpty) ?? false,
    ),
  ),
);
