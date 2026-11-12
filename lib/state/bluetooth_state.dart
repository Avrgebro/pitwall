import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/bluetooth/bluetooth_gateway.dart';
import '../core/platform/permission_gateway.dart';
import 'infrastructure.dart';
import 'permissions_state.dart';

/// The permission to find and connect to Bluetooth devices, asked for once
/// for whatever lists them together: Android takes one request at a time.
/// Asking goes through [permissionsProvider], so Settings and setup see
/// the answer too. Throws [BluetoothPermissionDenied] if it's refused.
///
/// Never retried on its own, which would ask again unbidden: Refresh asks.
final bluetoothAccessProvider = FutureProvider.autoDispose<void>((ref) async {
  final granted = await ref
      .read(permissionsProvider.notifier)
      .request(AppPermission.bluetooth);
  if (!granted) throw const BluetoothPermissionDenied();
}, retry: (_, _) => null);

/// Paired Bluetooth devices, once allowed to list them.
final pairedDevicesProvider = FutureProvider.autoDispose<List<BluetoothDevice>>(
  (ref) async {
    await ref.watch(bluetoothAccessProvider.future);
    return ref.read(bluetoothGatewayProvider).bondedDevices();
  },
  // What went wrong shows, and Refresh tries again.
  retry: (_, _) => null,
);

/// Bluetooth LE devices found nearby so far, once allowed to look, each
/// once, by address. Scanning lasts as long as something watches this, as
/// a picker does while it's open, and stops the moment nothing does.
///
/// Android stops a scan without a word when Bluetooth goes off, so that's
/// an error here, and a new scan starts when it's back on. Android also
/// allows only a few scans to start in half a minute, and quietly finds
/// nothing beyond, so one scan lasts the whole visit: refreshing the list
/// doesn't start another, unless this one failed.
final nearbyDevicesProvider = StreamProvider.autoDispose<List<BluetoothDevice>>(
  (ref) {
    final off = ref.watch(
      bluetoothOnProvider.select((on) => on.value == false),
    );
    if (off) {
      return Stream.error(
        PlatformException(code: 'disabled', message: 'Bluetooth is off'),
      );
    }
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
  // Retrying on its own would start scans towards that limit unseen.
  retry: (_, _) => null,
);

class BluetoothPermissionDenied implements Exception {
  const BluetoothPermissionDenied();
}
