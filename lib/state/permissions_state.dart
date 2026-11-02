import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform/permission_gateway.dart';
import 'infrastructure.dart';

/// Which permissions Pitwall has. Refresh when the app comes back to the
/// foreground, since the user can change them in Android settings.
final permissionsProvider =
    AsyncNotifierProvider<PermissionsNotifier, Map<AppPermission, bool>>(
      PermissionsNotifier.new,
    );

class PermissionsNotifier extends AsyncNotifier<Map<AppPermission, bool>> {
  PermissionGateway get _gateway => ref.read(permissionGatewayProvider);

  @override
  Future<Map<AppPermission, bool>> build() async => {
    for (final permission in AppPermission.values)
      permission: await _gateway.isGranted(permission),
  };

  /// Asks for [permission] and returns whether it's granted.
  Future<bool> request(AppPermission permission) async {
    // Otherwise the first check, still running, would overwrite the answer.
    await future;
    final granted = await _gateway.request(permission);
    state = AsyncData({...?state.value, permission: granted});
    return granted;
  }

  Future<void> refresh() async => state = AsyncData(await build());
}

/// How many permissions still need the user.
final missingPermissionsProvider = Provider<int>(
  (ref) =>
      ref.watch(permissionsProvider).value?.values.where((g) => !g).length ?? 0,
);
