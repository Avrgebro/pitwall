import 'package:material_ui/material_ui.dart';

import '../theme/emphasis.dart';
import '../theme/status_colors.dart';
import '../theme/tokens.dart';

/// A short status in a pill: background state, adapter, car, delivery.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
    this.emphasis = Emphasis.tonal,
    this.icon,
    this.dot = false,
    this.dense = false,
  });

  final String label;
  final StatusTone tone;
  final Emphasis emphasis;
  final IconData? icon;

  /// Shows a small dot before the label, for live states.
  final bool dot;

  /// Smaller, for use inside list items.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = context.tone(tone);
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (emphasis) {
      Emphasis.filled => (colors.accent, colors.onAccent),
      Emphasis.tonal => (colors.container, colors.onContainer),
      Emphasis.outlined => (Colors.transparent, scheme.onSurface),
    };
    final textStyle =
        (dense
                ? Theme.of(context).textTheme.labelSmall
                : Theme.of(context).textTheme.labelLarge)
            ?.copyWith(color: foreground, fontWeight: FontWeight.w600);
    final iconSize = dense ? 12.0 : 16.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? Insets.s : Insets.m,
        vertical: dense ? Insets.xxs : Insets.xsPlus,
      ),
      decoration: ShapeDecoration(
        color: background,
        shape: StadiumBorder(
          side: emphasis == Emphasis.outlined
              ? BorderSide(color: scheme.outline)
              : BorderSide.none,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot)
            Container(
              width: iconSize / 2,
              height: iconSize / 2,
              decoration: BoxDecoration(
                color: foreground,
                shape: BoxShape.circle,
              ),
            )
          else if (icon != null)
            Icon(icon, size: iconSize, color: foreground),
          if (dot || icon != null)
            SizedBox(width: dense ? Insets.xs : Insets.s),
          Text(label, style: textStyle),
        ],
      ),
    );
  }
}
