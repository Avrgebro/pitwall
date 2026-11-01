import 'package:permission_handler/permission_handler.dart';

/// What Pitwall needs from Android to run on its own.
enum AppPermission {
  /// Connecting to the adapter.
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

  static Permission _permission(AppPermission permission) =>
      switch (permission) {
        AppPermission.bluetooth => Permission.bluetoothConnect,
        AppPermission.notifications => Permission.notification,
        AppPermission.batteryOptimisation =>
          Permission.ignoreBatteryOptimizations,
      };

  @override
  Future<bool> isGranted(AppPermission permission) =>
      _permission(permission).isGranted;

  @override
  Future<bool> request(AppPermission permission) async =>
      (await _permission(permission).request()).isGranted;
}
