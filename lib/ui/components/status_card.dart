import 'package:material_ui/material_ui.dart';

import '../theme/status_colors.dart';
import '../theme/tokens.dart';
import 'icon_badge.dart';
import 'stat_tile.dart';

/// A status with an icon, a sentence and optional details: delivery health,
/// queued readings, failures. Warning and error states are filled so
/// problems stand out; other states are outlined.
class StatusCard extends StatelessWidget {
  const StatusCard({
    super.key,
    required this.tone,
    required this.icon,
    required this.title,
    required this.message,
    this.stats = const [],
    this.actions = const [],
    this.trailing,
  });

  final StatusTone tone;
  final IconData icon;
  final String title;
  final String message;

  /// Figures under a divider ("Last sent · Failed · Queued").
  final List<({String label, String value})> stats;

  /// Buttons at the bottom.
  final List<Widget> actions;

  /// A widget beside the text, such as a compact action.
  final Widget? trailing;

  bool get _filled => tone == StatusTone.warning || tone == StatusTone.error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.tone(tone);
    final scheme = theme.colorScheme;
    final titleColor = _filled ? colors.onContainer : scheme.onSurface;
    final bodyColor = _filled ? colors.onContainer : scheme.onSurfaceVariant;

    return Container(
      padding: Insets.card,
      decoration: BoxDecoration(
        color: _filled ? colors.container : scheme.surface,
        borderRadius: Corners.extraLargeRadius,
        border: _filled ? null : Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBadge(
                icon: icon,
                tone: tone,
                shape: BoxShape.circle,
                strong: _filled,
              ),
              const SizedBox(width: Insets.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: bodyColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: Insets.s),
                trailing!,
              ],
            ],
          ),
          if (stats.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Insets.m),
              child: Divider(color: bodyColor.withValues(alpha: 0.25)),
            ),
            LabeledValueRow(items: stats, color: titleColor),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: Insets.m),
            Wrap(spacing: Insets.s, runSpacing: Insets.s, children: actions),
          ],
        ],
      ),
    );
  }
}

/// The outcome of an action, right below it ("Test reading delivered").
class ResultBanner extends StatelessWidget {
  const ResultBanner({
    super.key,
    required this.tone,
    required this.title,
    required this.message,
  });

  final StatusTone tone;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.tone(tone);
    final healthy = tone == StatusTone.healthy || tone == StatusTone.active;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.l,
        vertical: Insets.m,
      ),
      decoration: BoxDecoration(
        color: colors.container,
        borderRadius: Corners.largeRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            healthy ? Icons.check_circle : Icons.error,
            size: Sizes.iconSmall,
            color: colors.onContainer,
          ),
          const SizedBox(width: Insets.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.onContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
