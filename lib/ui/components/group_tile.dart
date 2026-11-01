import 'package:material_ui/material_ui.dart';

import '../theme/text_styles.dart';

/// A row inside a [GroupCard]: icon, title, subtitle or monospace caption,
/// and a trailing widget. With [onTap] and no trailing, shows a chevron.
class GroupTile extends StatelessWidget {
  const GroupTile({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    this.caption,
    this.trailing,
    this.onTap,
  });

  final String title;
  final IconData? icon;
  final String? subtitle;

  /// A technical detail shown in monospace, such as a payload key.
  final String? caption;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: icon == null ? null : Icon(icon),
      title: Text(title),
      subtitle: switch ((subtitle, caption)) {
        (final text?, _) => Text(text),
        (null, final code?) => Text(
          code,
          style: theme.textTheme.mono.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        _ => null,
      },
      trailing:
          trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right)),
      onTap: onTap,
    );
  }
}
