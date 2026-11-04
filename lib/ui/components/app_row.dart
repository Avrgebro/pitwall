import 'package:material_ui/material_ui.dart';

import '../theme/status_colors.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';

/// The row every list row is: leading widget, title, optional subtitle,
/// trailing widget. Row components build on this so they all line up.
class AppRow extends StatelessWidget {
  const AppRow({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.subtitleTone,
    this.trailing,
    this.opensPage = false,
    this.onTap,
    this.tone,
    this.enabled = true,
  });

  /// Horizontal padding of a row.
  static const _inset = Insets.lPlus;

  final String title;

  /// An icon here takes the row's accent colour unless it sets its own.
  final Widget? leading;
  final Widget? subtitle;

  /// Colours the subtitle, e.g. error for "Choose its adapter".
  final StatusTone? subtitleTone;
  final Widget? trailing;

  /// Ends the row with the arrow of a row that opens a page, after
  /// [trailing].
  final bool opensPage;
  final VoidCallback? onTap;

  /// Colours the title and leading icon, e.g. error for "Delete vehicle".
  final StatusTone? tone;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = this.tone;
    final subtitleTone = this.subtitleTone;
    final leading = this.leading;
    final subtitle = this.subtitle;
    final trailing = this.trailing;
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
              child: Center(
                child: IconTheme.merge(
                  data: IconThemeData(
                    color: tone == null
                        ? theme.colorScheme.primary
                        : context.tone(tone).accent,
                  ),
                  child: leading,
                ),
              ),
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
                    color: tone == null
                        ? theme.colorScheme.onSurface
                        : context.tone(tone).accent,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: Insets.xxs),
                  DefaultTextStyle.merge(
                    style: theme.textTheme.rowSubtitle.copyWith(
                      color: subtitleTone == null
                          ? theme.colorScheme.onSurfaceVariant
                          : context.tone(subtitleTone).accent,
                    ),
                    child: subtitle,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: Insets.m), trailing],
          if (opensPage) ...[
            SizedBox(width: trailing == null ? Insets.m : Insets.s),
            Icon(Icons.chevron_right, color: theme.colorScheme.primary),
          ],
        ],
      ),
    );
    final row = onTap == null || !enabled
        ? content
        : InkWell(onTap: onTap, child: content);
    return enabled ? row : Opacity(opacity: Opacities.disabled, child: row);
  }
}
