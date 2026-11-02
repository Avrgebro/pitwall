import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/bluetooth/bluetooth_gateway.dart';
import '../core/platform/permission_gateway.dart';
import 'infrastructure.dart';
import 'permissions_state.dart';

/// Paired Bluetooth devices, after asking for the permission to list them.
/// Asking goes through [permissionsProvider], so Settings and setup see
/// the answer too.
final pairedDevicesProvider = FutureProvider.autoDispose<List<BondedDevice>>((
  ref,
) async {
  final granted = await ref
      .read(permissionsProvider.notifier)
      .request(AppPermission.bluetooth);
  if (!granted) throw const BluetoothPermissionDenied();
  return ref.read(bluetoothGatewayProvider).bondedDevices();
});

class BluetoothPermissionDenied implements Exception {
  const BluetoothPermissionDenied();
}
