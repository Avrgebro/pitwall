import 'package:material_ui/material_ui.dart';

import '../theme/status_colors.dart';
import '../theme/text_styles.dart';
import 'app_row.dart';
import 'expandable_row.dart';
import 'row_group.dart';

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
    return AppRow(
      title: title,
      leading: Icon(
        done ? Icons.check_circle : Icons.error,
        color: colors.accent,
      ),
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
    this.warning,
  });

  final String title;

  /// A technical detail shown in monospace, such as a payload key.
  final String? caption;

  /// Something about it that needs noticing, shown under the caption.
  final String? warning;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final caption = this.caption;
    final warning = this.warning;
    final theme = Theme.of(context);
    return AppRow(
      title: title,
      subtitle: caption == null && warning == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (caption != null) Text(caption, style: theme.textTheme.mono),
                if (warning != null)
                  Text(
                    warning,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.tone(StatusTone.warning).accent,
                    ),
                  ),
              ],
            ),
      trailing: Checkbox(
        value: value,
        onChanged: (checked) => onChanged(checked ?? false),
      ),
      onTap: () => onChanged(!value),
    );
  }
}

/// One option of several, inside a `RadioGroup<T>`. Tapping anywhere on
/// the row selects it. [child] opens under the option while it's selected,
/// across the full width of the card: fields or a follow-up choice for
/// that option.
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.value,
    required this.title,
    this.subtitle,
    this.badge,
    this.enabled = true,
    this.child,
  });

  final T value;
  final String title;
  final String? subtitle;

  /// A small label right after the title; see [AppRow.badge].
  final Widget? badge;
  final bool enabled;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final group = RadioGroup.maybeOf<T>(context);
    final selected = group?.groupValue == value;
    // The selected option outlines its segment in the accent colour.
    final primary = Theme.of(context).colorScheme.primary;
    Widget outlined(Widget option) => AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      foregroundDecoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          borderRadius: RowSegment.borderRadiusOf(context),
          side: BorderSide(
            color: selected ? primary : primary.withValues(alpha: 0),
            width: 1,
          ),
        ),
      ),
      child: option,
    );
    final row = AppRow(
      title: title,
      enabled: enabled,
      leading: Radio<T>(value: value, enabled: enabled),
      subtitle: subtitle == null ? null : Text(subtitle!),
      badge: badge,
      onTap: child == null ? () => group?.onChanged(value) : null,
    );
    return switch (child) {
      null => outlined(row),
      final child => outlined(
        ExpandableRow(
          row: row,
          open: selected,
          onTap: enabled ? () => group?.onChanged(value) : null,
          child: child,
        ),
      ),
    };
  }
}
