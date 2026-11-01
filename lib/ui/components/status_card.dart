import 'package:material_ui/material_ui.dart';

import '../theme/status_colors.dart';
import '../theme/tokens.dart';
import 'detail_rows.dart';
import 'glass_surface.dart';
import 'icon_badge.dart';
import 'line_icon.dart';

/// A status with an icon, an optional sentence and details: delivery
/// health, queued readings, failures. Warning and error states are filled
/// so problems stand out; other states are glass like the cards around.
class StatusCard extends StatelessWidget {
  const StatusCard({
    super.key,
    required this.tone,
    required this.icon,
    required this.title,
    this.message,
    this.stats = const [],
    this.actions = const [],
    this.trailing,
  });

  final StatusTone tone;
  final IconData icon;
  final String title;

  /// What it means, when the title doesn't say it all.
  final String? message;

  /// Details as rows ("Last sent", "Failed", "Queued").
  final List<({IconData icon, String label, String value})> stats;

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

    final content = Padding(
      padding: Insets.card,
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
                    if (message case final message?)
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
            const SizedBox(height: Insets.l),
            DetailRows(
              rows: stats,
              color: titleColor,
              background: _filled
                  ? colors.onContainer.withValues(alpha: 0.08)
                  : scheme.surface.withValues(alpha: 0.4),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: Insets.m),
            Wrap(spacing: Insets.s, runSpacing: Insets.s, children: actions),
          ],
        ],
      ),
    );
    if (!_filled) return GlassSurface(child: content);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.container,
        borderRadius: Corners.extraLargeRadius,
      ),
      child: content,
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
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      color: colors.onContainer,
      fontWeight: FontWeight.w600,
    );
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
          LineIcon(
            healthy ? Icons.check_circle : Icons.error,
            style: titleStyle,
            size: Sizes.iconSmall,
            color: colors.onContainer,
          ),
          const SizedBox(width: Insets.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: titleStyle),
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
