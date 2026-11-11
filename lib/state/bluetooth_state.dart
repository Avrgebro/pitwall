import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/bluetooth/bluetooth_gateway.dart';
import '../core/platform/permission_gateway.dart';
import 'infrastructure.dart';
import 'permissions_state.dart';

/// The permission to find and connect to Bluetooth devices, asked for once
/// for whatever lists them together: Android takes one request at a time.
/// Asking goes through [permissionsProvider], so Settings and setup see
/// the answer too. Throws [BluetoothPermissionDenied] if it's refused.
final bluetoothAccessProvider = FutureProvider.autoDispose<void>((ref) async {
  final granted = await ref
      .read(permissionsProvider.notifier)
      .request(AppPermission.bluetooth);
  if (!granted) throw const BluetoothPermissionDenied();
});

/// Paired Bluetooth devices, once allowed to list them.
final pairedDevicesProvider = FutureProvider.autoDispose<List<BluetoothDevice>>(
  (ref) async {
    await ref.watch(bluetoothAccessProvider.future);
    return ref.read(bluetoothGatewayProvider).bondedDevices();
  },
);

/// Bluetooth LE devices found nearby so far, once allowed to look, each
/// once, by address. Scanning lasts as long as something watches this, as
/// a picker does while it's open, and stops the moment nothing does.
final nearbyDevicesProvider = StreamProvider.autoDispose<List<BluetoothDevice>>(
  (ref) {
    final access = ref.watch(bluetoothAccessProvider.future);
    final gateway = ref.read(bluetoothGatewayProvider);
    final found = StreamController<List<BluetoothDevice>>();
    StreamSubscription<BluetoothDevice>? scan;
    // Cancelled here, not when a generator next yields: with nothing new
    // found, that would be never, and the scan would go on.
    ref.onDispose(() {
      scan?.cancel();
      found.close();
    });
    access.then(
      (_) {
        if (found.isClosed) return;
        final byAddress = <String, BluetoothDevice>{};
        found.add(const []);
        scan = gateway.nearbyDevices().listen((device) {
          if (byAddress[device.address]?.name == device.name) return;
          byAddress[device.address] = device;
          found.add([...byAddress.values]);
        }, onError: found.addError);
      },
      onError: (Object error, StackTrace stack) {
        if (!found.isClosed) found.addError(error, stack);
      },
    );
    return found.stream;
  },
);

class BluetoothPermissionDenied implements Exception {
  const BluetoothPermissionDenied();
}
