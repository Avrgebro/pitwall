import 'package:material_ui/material_ui.dart';

import '../theme/emphasis.dart';
import '../theme/status_colors.dart';
import '../theme/tokens.dart';

/// An icon on a tinted square or circle: vehicle, profile, permission,
/// status icons.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    this.tone = StatusTone.active,
    this.size = Sizes.badge,
    this.shape = BoxShape.rectangle,
    this.emphasis = Emphasis.tonal,
  });

  final IconData icon;
  final StatusTone tone;
  final double size;
  final BoxShape shape;

  final Emphasis emphasis;

  @override
  Widget build(BuildContext context) {
    final colors = context.tone(tone);
    final (fill, foreground) = switch (emphasis) {
      Emphasis.filled => (colors.accent, colors.onAccent),
      Emphasis.tonal => (colors.container, colors.onContainer),
      Emphasis.outlined => (null, colors.accent),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        border: emphasis == Emphasis.outlined
            ? Border.all(color: colors.accent)
            : null,
        shape: shape,
        borderRadius: shape == BoxShape.rectangle
            ? BorderRadius.circular(size * 0.3)
            : null,
      ),
      child: Icon(icon, size: size * 0.5, color: foreground),
    );
  }
}
