import 'package:material_ui/material_ui.dart';

import '../theme/status_colors.dart';
import '../theme/tokens.dart';

/// Title of a group on a page, with optional meta text on the right
/// ("Last values sent ······ Updated 40 s ago").
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
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
  final String? trailing;

  /// Colours the trailing text, e.g. error for "1 needs fixing".
  final StatusTone? trailingTone;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
      ),
    );
  }
}
