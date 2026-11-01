import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/platform/permission_gateway.dart';
import '../../state/permissions_state.dart';
import '../../ui/ui.dart';
import '../common/permission_text.dart';

/// What Android must allow for Pitwall to run on its own.
class BackgroundChecksScreen extends ConsumerWidget {
  const BackgroundChecksScreen({super.key});

  /// What keeps Pitwall alive first.
  static const _order = [
    AppPermission.batteryOptimisation,
    AppPermission.bluetooth,
    AppPermission.notifications,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(permissionsProvider).value ?? const {};
    return AppPage(
      title: 'Background checks',
      children: [
        RowGroup(
          children: [
            for (final permission in _order)
              Builder(
                builder: (context) {
                  final granted = permissions[permission] ?? false;
                  final text = PermissionText.check(
                    permission,
                    granted: granted,
                  );
                  return ChecklistRow(
                    title: text.title,
                    subtitle: text.status,
                    done: granted,
                    onFix: () => ref
                        .read(permissionsProvider.notifier)
                        .request(permission),
                  );
                },
              ),
          ],
        ),
        const InfoNote(
          text: TextSpan(
            text:
                'These let Pitwall start and keep running during a drive, '
                'with the app closed and the screen off.',
          ),
        ),
      ],
    );
  }
}
