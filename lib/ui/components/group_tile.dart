import 'package:material_ui/material_ui.dart';

import '../theme/status_colors.dart';
import '../theme/text_styles.dart';
import 'row_layout.dart';

/// A row in a `RowGroup`: accent icon, title, subtitle or monospace caption,
/// and a trailing widget. With [onTap] and no trailing, shows a chevron.
class GroupTile extends StatelessWidget {
  const GroupTile({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    this.subtitleTone,
    this.caption,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final String title;
  final IconData? icon;
  final String? subtitle;

  /// Colours the subtitle, e.g. error for "1 needs fixing".
  final StatusTone? subtitleTone;

  /// A technical detail shown in monospace, such as a payload key.
  final String? caption;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// An action that removes something: shown in the error colour.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = destructive
        ? context.tone(StatusTone.error).accent
        : theme.colorScheme.primary;
    return RowLayout(
      title: title,
      titleColor: destructive ? accent : null,
      leading: icon == null ? null : Icon(icon, color: accent),
      subtitle: switch ((subtitle, caption)) {
        (final text?, _) => Text(
          text,
          style: subtitleTone == null
              ? null
              : TextStyle(color: context.tone(subtitleTone!).accent),
        ),
        (null, final code?) => Text(code, style: theme.textTheme.mono),
        _ => null,
      },
      trailing:
          trailing ??
          (onTap == null || destructive
              ? null
              : Icon(Icons.chevron_right, color: accent)),
      onTap: onTap,
    );
  }
}
