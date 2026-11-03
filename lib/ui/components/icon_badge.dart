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
    this.filled = false,
  });

  final IconData icon;
  final StatusTone tone;
  final double size;
  final BoxShape shape;

  /// In the tone's strong colour, as on a tinted card; otherwise in its
  /// soft container colour.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colors = context.tone(tone);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? colors.accent : colors.container,
        shape: shape,
        borderRadius: shape == BoxShape.rectangle
            ? BorderRadius.circular(size * 0.3)
            : null,
      ),
      child: Icon(
        icon,
        size: size * 0.5,
        color: filled ? colors.onAccent : colors.onContainer,
      ),
    );
  }
}
