import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../ui/ui.dart';
import '../home_view_model.dart';

/// Delivery health on Home: healthy, queued (nothing to do), failing
/// (needs the user) or not set up, with the actions that help.
class DeliveryStatusCard extends StatelessWidget {
  const DeliveryStatusCard({
    super.key,
    required this.model,
    required this.onOpenSettings,
    required this.onSetWebhook,
    required this.onRetry,
  });

  final DeliveryCardModel model;
  final VoidCallback onOpenSettings;
  final VoidCallback onSetWebhook;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.tone(model.tone);
    return StatusCard(
      tone: model.tone,
      icon: switch (model.kind) {
        DeliveryCardKind.healthy => Symbols.cloud_done_rounded,
        DeliveryCardKind.queued => Symbols.cloud_off_rounded,
        DeliveryCardKind.failing => Symbols.error_rounded,
        DeliveryCardKind.noWebhook => Symbols.webhook_rounded,
      },
      title: model.title,
      message: model.message,
      stats: [
        for (final stat in model.stats)
          (icon: _icon(stat.kind), label: stat.label, value: stat.value),
      ],
      actions: [
        if (model.canSetWebhook)
          FilledButton.icon(
            onPressed: onSetWebhook,
            style: FilledButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: colors.onAccent,
            ),
            icon: const Icon(Symbols.webhook_rounded),
            label: const Text('Set webhook'),
          ),
        if (model.canOpenSettings)
          FilledButton.icon(
            onPressed: onOpenSettings,
            style: FilledButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: colors.onAccent,
            ),
            icon: const Icon(Symbols.settings_rounded),
            label: const Text('Check Settings'),
          ),
        if (model.canRetry && model.kind == DeliveryCardKind.failing)
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(foregroundColor: colors.onContainer),
            child: const Text('Retry now'),
          ),
      ],
    );
  }

  static IconData _icon(DeliveryStatKind kind) => switch (kind) {
    DeliveryStatKind.lastSent => Symbols.schedule_send_rounded,
    DeliveryStatKind.failed => Symbols.sync_problem_rounded,
    DeliveryStatKind.queued => Symbols.pending_rounded,
  };
}
