import 'package:material_ui/material_ui.dart';

import '../theme/status_colors.dart';
import '../theme/text_styles.dart';
import 'row_layout.dart';

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
    return RowLayout(
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
  });

  final String title;

  /// A technical detail shown in monospace, such as a payload key.
  final String? caption;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => RowLayout(
    title: title,
    subtitle: caption == null
        ? null
        : Text(caption!, style: Theme.of(context).textTheme.mono),
    trailing: Checkbox(
      value: value,
      onChanged: (checked) => onChanged(checked ?? false),
    ),
    onTap: () => onChanged(!value),
  );
}

/// One option of several, inside a `RadioGroup<T>`. Tapping anywhere on
/// the row selects it. [child] shows extra content under the selected
/// option, such as a follow-up choice.
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.value,
    required this.title,
    this.subtitle,
    this.enabled = true,
    this.child,
  });

  final T value;
  final String title;
  final String? subtitle;
  final bool enabled;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final group = RadioGroup.maybeOf<T>(context);
    final row = RowLayout(
      title: title,
      enabled: enabled,
      leading: Radio<T>(value: value, enabled: enabled),
      subtitle: subtitle == null ? null : Text(subtitle!),
      onTap: () => group?.onChanged(value),
    );
    if (child == null) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [row, child!],
    );
  }
}
