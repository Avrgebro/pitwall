import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/platform/permission_gateway.dart';
import '../../../state/permissions_state.dart';
import '../../../ui/ui.dart';
import '../../common/permission_text.dart';
import '../widgets/permission_card.dart';

/// The three permissions, each with why it's needed.
class PermissionsStep extends ConsumerWidget {
  const PermissionsStep({super.key});

  static IconData _icon(AppPermission permission) => switch (permission) {
    AppPermission.bluetooth => Symbols.bluetooth_rounded,
    AppPermission.notifications => Symbols.notifications_rounded,
    AppPermission.batteryOptimisation => Symbols.battery_plus_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final granted = ref.watch(permissionsProvider).value ?? const {};
    return Column(
      children: [
        for (final permission in AppPermission.values) ...[
          PermissionCard(
            icon: _icon(permission),
            title: PermissionText.title(permission),
            purpose: PermissionText.purpose(permission),
            granted: granted[permission] ?? false,
            onAllow: () =>
                ref.read(permissionsProvider.notifier).request(permission),
          ),
          const SizedBox(height: Insets.m),
        ],
      ],
    );
  }
}
