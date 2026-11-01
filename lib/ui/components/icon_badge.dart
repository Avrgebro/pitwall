import 'package:material_ui/material_ui.dart';

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
    this.strong = false,
  });

  final IconData icon;
  final StatusTone tone;
  final double size;
  final BoxShape shape;

  /// Uses the tone's accent colour instead of its soft container colour.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final colors = context.tone(tone);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: strong ? colors.accent : colors.container,
        shape: shape,
        borderRadius: shape == BoxShape.rectangle
            ? BorderRadius.circular(size * 0.3)
            : null,
      ),
      child: Icon(
        icon,
        size: size * 0.5,
        color: strong ? colors.onAccent : colors.onContainer,
      ),
    );
  }
}
