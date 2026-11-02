import 'package:material_ui/material_ui.dart';

import '../theme/status_colors.dart';
import '../theme/tokens.dart';
import 'line_icon.dart';

/// Title of a group on a page, with optional meta text on the right
/// ("Last values sent" on the left, "Updated 40 s ago" on the right).
///
/// With an [icon], it's the quieter settings style: an accent icon and a
/// plain label. Without one, the label itself carries the accent colour.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.icon,
    this.trailing,
    this.trailingTone,
    this.padding = const EdgeInsets.fromLTRB(
      Insets.xs,
      Insets.xl,
      Insets.xs,
      Insets.s,
    ),
  });

  final String title;
  final IconData? icon;
  final String? trailing;

  /// Colours the trailing text, e.g. error for "1 needs fixing".
  final StatusTone? trailingTone;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle =
        (icon == null
                ? theme.textTheme.titleSmall
                : theme.textTheme.titleMedium)
            ?.copyWith(
              color: icon == null
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            );
    // The texts share a baseline; the icon is centred on the title's line.
    final texts = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: Text(title, style: titleStyle)),
        if (trailing != null)
          Text(
            trailing!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: trailingTone == null
                  ? theme.colorScheme.onSurfaceVariant
                  : context.tone(trailingTone!).accent,
            ),
          ),
      ],
    );
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            LineIcon(
              icon!,
              style: titleStyle,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: Insets.m),
          ],
          Expanded(child: texts),
        ],
      ),
    );
  }
}
