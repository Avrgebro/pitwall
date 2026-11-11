import 'package:permission_handler/permission_handler.dart';

/// What Pitwall needs from Android to run on its own.
enum AppPermission {
  /// Finding the adapter, if it's Bluetooth LE, and connecting to it.
  bluetooth,

  /// The notification Android requires while Pitwall works in the
  /// background.
  notifications,

  /// Exemption from battery optimisation, so Android doesn't stop Pitwall
  /// before a drive.
  batteryOptimisation,
}

/// Checks and requests permissions, behind an interface so screens and
/// controllers can be tested without a phone.
abstract interface class PermissionGateway {
  Future<bool> isGranted(AppPermission permission);

  /// Asks the user. Returns whether it's granted afterwards.
  Future<bool> request(AppPermission permission);
}

class PermissionHandlerGateway implements PermissionGateway {
  const PermissionHandlerGateway();

  /// What Android asks for each; Bluetooth is two, asked for together, as
  /// Android shows them as one "Nearby devices" permission.
  static List<Permission> _permissions(AppPermission permission) =>
      switch (permission) {
        AppPermission.bluetooth => [
          Permission.bluetoothConnect,
          Permission.bluetoothScan,
        ],
        AppPermission.notifications => [Permission.notification],
        AppPermission.batteryOptimisation => [
          Permission.ignoreBatteryOptimizations,
        ],
      };

  @override
  Future<bool> isGranted(AppPermission permission) async {
    for (final each in _permissions(permission)) {
      if (!await each.isGranted) return false;
    }
    return true;
  }

  @override
  Future<bool> request(AppPermission permission) async {
    final statuses = await _permissions(permission).request();
    return statuses.values.every((status) => status.isGranted);
  }
}
