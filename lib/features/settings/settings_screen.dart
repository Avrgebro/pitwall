import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../state/infrastructure.dart';
import '../../state/permissions_state.dart';
import '../../state/settings_state.dart';
import '../../state/webhook_state.dart';
import '../../ui/ui.dart';
import 'settings_summary.dart';

/// The settings overview: one row per setting, each showing its current
/// state and opening its own page.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider).value;
    final webhook = ref.watch(webhookConfigProvider).value;
    if (settings == null || webhook == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final now = ref.watch(nowProvider);
    final info = ref.watch(packageInfoProvider).value;
    final webhookState = SettingsSummary.webhook(
      webhook,
      ref.watch(deliveryStatusProvider),
      now,
    );
    final checks = SettingsSummary.checks(
      ref.watch(missingPermissionsProvider),
    );
    StatusTone? tone(bool problem) => problem ? StatusTone.error : null;

    return AppPage(
      title: 'Settings',
      children: [
        const SectionHeader(
          'Delivery',
          icon: Symbols.cloud_upload_rounded,
          padding: EdgeInsets.fromLTRB(Insets.xs, 0, Insets.xs, Insets.m),
        ),
        RowGroup(
          children: [
            GroupTile(
              icon: Symbols.webhook_rounded,
              title: 'Webhook',
              subtitle: webhookState.text,
              subtitleTone: tone(webhookState.problem),
              onTap: () => context.push(Routes.webhookSettings),
            ),
            GroupTile(
              icon: Symbols.timer_rounded,
              title: 'Reading interval',
              subtitle: Formatters.interval(settings.interval),
              onTap: () => context.push(Routes.intervalSettings),
            ),
          ],
        ),
        const SectionHeader('Trips', icon: Symbols.route_rounded),
        RowGroup(
          children: [
            GroupTile(
              icon: Symbols.verified_user_rounded,
              title: 'Background checks',
              subtitle: checks.text,
              subtitleTone: tone(checks.problem),
              onTap: () => context.push(Routes.backgroundChecks),
            ),
          ],
        ),
        const SectionHeader('About', icon: Symbols.info_rounded),
        RowGroup(
          children: [
            GroupTile(
              icon: Symbols.directions_car_rounded,
              title: 'About Pitwall',
              subtitle: info == null
                  ? 'Licence and credits'
                  : 'Version ${info.version} · licence and credits',
              onTap: () => context.push(Routes.about),
            ),
          ],
        ),
        const SectionHeader('Developer', icon: Symbols.code_rounded),
        RowGroup(
          children: [
            GroupTile(
              icon: Symbols.terminal_rounded,
              title: 'Developer tools',
              subtitle: 'Adapter log, raw commands and test trips',
              onTap: () => context.push(Routes.developer),
            ),
          ],
        ),
      ],
    );
  }
}
