import 'package:material_ui/material_ui.dart';

import '../theme/status_colors.dart';
import '../theme/text_styles.dart';

/// An item that's either done or needs fixing, with a fix action.
class ChecklistRow extends StatelessWidget {
  const ChecklistRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.done,
    this.onFix,
    this.fixLabel = 'Fix',
  });

  final String title;
  final String subtitle;
  final bool done;
  final VoidCallback? onFix;
  final String fixLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.tone(done ? StatusTone.healthy : StatusTone.error);
    return ListTile(
      leading: Icon(
        done ? Icons.check_circle : Icons.error,
        color: colors.accent,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: done || onFix == null
          ? null
          : FilledButton.tonal(
              onPressed: onFix,
              style: FilledButton.styleFrom(minimumSize: const Size(48, 36)),
              child: Text(fixLabel),
            ),
    );
  }
}

/// A value that can be switched on or off, with its payload key below.
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.caption,
  });

  final String title;

  /// A technical detail shown in monospace, such as a payload key.
  final String? caption;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CheckboxListTile(
      value: value,
      onChanged: (checked) => onChanged(checked ?? false),
      title: Text(title),
      subtitle: caption == null
          ? null
          : Text(
              caption!,
              style: theme.textTheme.mono.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
    );
  }
}
