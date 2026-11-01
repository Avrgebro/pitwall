import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/links.dart';
import '../../app/routes.dart';
import '../../core/platform/permission_gateway.dart';
import '../../core/settings/settings.dart';
import '../../state/infrastructure.dart';
import '../../state/permissions_state.dart';
import '../../state/settings_state.dart';
import '../../ui/ui.dart';
import '../common/permission_text.dart';
import 'widgets/wake_section.dart';
import '../common/widgets/webhook_section.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Permissions can change in Android settings while Pitwall is away.
  late final _lifecycle = AppLifecycleListener(
    onResume: () => ref.read(permissionsProvider.notifier).refresh(),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider).value;
    if (settings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final missing = ref.watch(missingPermissionsProvider);

    return AppPage(
      title: 'Settings',
      children: [
        const SectionHeader(
          'Webhook',
          padding: EdgeInsets.fromLTRB(Insets.xs, 0, Insets.xs, Insets.s),
        ),
        const WebhookSection(),
        const SectionHeader('Reading'),
        GroupCard(
          children: [
            SelectTile<Duration>(
              icon: Symbols.timer_rounded,
              title: 'Reading interval',
              value: settings.interval,
              options: AppSettings.intervalChoices,
              labelOf: Formatters.interval,
              onChanged: ref.read(appSettingsProvider.notifier).setInterval,
            ),
          ],
        ),
        const SectionHeader('What wakes Pitwall'),
        WakeSection(settings: settings),
        SectionHeader(
          'Background checks',
          trailing: missing == 0 ? null : '$missing needs fixing',
          trailingTone: StatusTone.error,
        ),
        const _BackgroundChecks(),
        const SectionHeader('About'),
        const _About(),
        const SectionHeader('Developer tools'),
        GroupCard(
          children: [
            GroupTile(
              icon: Symbols.terminal_rounded,
              title: 'Raw adapter log',
              subtitle: 'Commands, replies and sends',
              onTap: () => context.push(Routes.developer),
            ),
          ],
        ),
      ],
    );
  }
}

class _BackgroundChecks extends ConsumerWidget {
  const _BackgroundChecks();

  /// In the order the mockups list them: what keeps Pitwall alive first.
  static const _order = [
    AppPermission.batteryOptimisation,
    AppPermission.bluetooth,
    AppPermission.notifications,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(permissionsProvider).value ?? const {};
    return GroupCard(
      children: [
        for (final permission in _order)
          Builder(
            builder: (context) {
              final granted = permissions[permission] ?? false;
              final text = PermissionText.check(permission, granted: granted);
              return ChecklistRow(
                title: text.title,
                subtitle: text.status,
                done: granted,
                onFix: () =>
                    ref.read(permissionsProvider.notifier).request(permission),
              );
            },
          ),
      ],
    );
  }
}

class _About extends ConsumerWidget {
  const _About();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(packageInfoProvider).value;
    return GroupCard(
      children: [
        GroupTile(
          icon: Symbols.info_rounded,
          title: 'Version',
          subtitle: info == null
              ? '…'
              : '${info.version} (${info.buildNumber})',
        ),
        GroupTile(
          icon: Symbols.balance_rounded,
          title: 'Open-source licence',
          subtitle: 'MIT',
          trailing: const Icon(Symbols.open_in_new_rounded),
          onTap: () => launchUrl(Links.licence),
        ),
        GroupTile(
          icon: Symbols.favorite_rounded,
          title: 'Credits',
          subtitle:
              'Vehicle profiles from the OBDb community database. '
              'Open-source libraries.',
          onTap: () => context.push(Routes.credits),
        ),
      ],
    );
  }
}
