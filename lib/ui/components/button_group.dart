import 'package:material_ui/material_ui.dart';

import '../theme/glass_colors.dart';
import '../theme/status_colors.dart';
import '../theme/tokens.dart';

/// One button in a [ButtonGroup]: an icon, and a label for the main ones.
@immutable
class GroupButton {
  const GroupButton({
    required this.icon,
    required this.onPressed,
    this.label,
    this.tooltip,
    this.tone,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  /// Shown beside the icon. A button with a label takes the spare width;
  /// one without stays icon-sized and needs a [tooltip].
  final String? label;
  final String? tooltip;

  /// Colours the icon and label, e.g. error for a button that removes.
  final StatusTone? tone;
}

/// Related actions as connected segments, like Material 3's expressive
/// button groups: rounded at the ends of the group, nearly square where
/// segments meet, the same shape as a `RowGroup`'s rows. For use inside a
/// card.
class ButtonGroup extends StatelessWidget {
  const ButtonGroup({super.key, required this.buttons});

  final List<GroupButton> buttons;

  static const _height = 48.0;
  static const _iconWidth = 64.0;
  static const _outer = Radius.circular(_height / 2);
  static const _inner = Radius.circular(Corners.segment);

  @override
  Widget build(BuildContext context) {
    final last = buttons.length - 1;
    return SizedBox(
      height: _height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i <= last; i++) ...[
            if (i > 0) const SizedBox(width: Insets.segment),
            if (buttons[i].label == null)
              SizedBox(
                width: _iconWidth,
                child: _segment(context, buttons[i], i == 0, i == last),
              )
            else
              Expanded(child: _segment(context, buttons[i], i == 0, i == last)),
          ],
        ],
      ),
    );
  }

  Widget _segment(
    BuildContext context,
    GroupButton button,
    bool first,
    bool last,
  ) {
    final theme = Theme.of(context);
    final tone = button.tone;
    final enabled = button.onPressed != null;
    final color =
        (tone == null ? theme.colorScheme.onSurface : context.tone(tone).accent)
            .withValues(alpha: enabled ? 1 : disabledOpacity);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.horizontal(
        left: first ? _outer : _inner,
        right: last ? _outer : _inner,
      ),
      side: BorderSide(color: context.glass.edge),
    );
    final label = button.label;
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(button.icon, color: color, size: Sizes.iconSmall + 2),
        if (label != null) ...[
          const SizedBox(width: Insets.s),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
    final segment = Material(
      color: context.glass.panel,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: button.onPressed, child: content),
    );
    final tooltip = button.tooltip;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label == null ? tooltip : null,
      child: tooltip == null
          ? segment
          : Tooltip(message: tooltip, child: segment),
    );
  }
}
