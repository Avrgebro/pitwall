import 'package:material_ui/material_ui.dart';

import '../theme/text_styles.dart';
import '../theme/tokens.dart';

/// The layout every row shares: leading widget, title, optional subtitle,
/// trailing widget. Row components build on this so they all line up.
class RowLayout extends StatelessWidget {
  const RowLayout({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
    this.enabled = true,
  });

  /// Horizontal padding of a row.
  static const _inset = Insets.lPlus;

  final String title;
  final Widget? leading;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Overrides the title colour, e.g. for destructive rows.
  final Color? titleColor;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _inset,
        vertical: Insets.l,
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            SizedBox(
              width: Sizes.icon,
              child: Center(child: leading),
            ),
            const SizedBox(width: _inset),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.rowTitle.copyWith(
                    color: titleColor ?? theme.colorScheme.onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: Insets.xxs),
                  DefaultTextStyle.merge(
                    style: theme.textTheme.rowSubtitle.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    child: subtitle!,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: Insets.m), trailing!],
        ],
      ),
    );
    final row = onTap == null || !enabled
        ? content
        : InkWell(onTap: onTap, child: content);
    return enabled ? row : Opacity(opacity: 0.45, child: row);
  }
}
