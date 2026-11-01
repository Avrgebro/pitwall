import '../../core/platform/permission_gateway.dart';

/// Plain-language wording for the permissions Pitwall needs, shared by
/// Settings and setup.
abstract final class PermissionText {
  static String title(AppPermission permission) => switch (permission) {
    AppPermission.bluetooth => 'Bluetooth',
    AppPermission.notifications => 'Notifications',
    AppPermission.batteryOptimisation => 'Battery optimisation',
  };

  /// Why it's needed, for setup.
  static String purpose(AppPermission permission) => switch (permission) {
    AppPermission.bluetooth => 'To talk to the adapter in your car.',
    AppPermission.notifications =>
      'Android needs a small notification while Pitwall works in the '
          'background.',
    AppPermission.batteryOptimisation =>
      'Turn it off so Android doesn\'t put Pitwall to sleep before you '
          'drive.',
  };

  /// A checklist line for Settings.
  static ({String title, String status}) check(
    AppPermission permission, {
    required bool granted,
  }) => switch (permission) {
    AppPermission.bluetooth => (
      title: 'Bluetooth permission',
      status: granted
          ? 'Allowed'
          : 'Not allowed. Pitwall can\'t talk to the adapter.',
    ),
    AppPermission.notifications => (
      title: 'Notifications',
      status: granted
          ? 'Allowed'
          : 'Off. Android may stop Pitwall without one.',
    ),
    AppPermission.batteryOptimisation => (
      title: granted ? 'Battery optimisation off' : 'Battery optimisation on',
      status: granted
          ? 'Pitwall can run with the screen off'
          : 'Android may put Pitwall to sleep before you drive.',
    ),
  };
}
