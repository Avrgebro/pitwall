import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// An icon on a scalloped Material 3 Expressive shape, with an optional
/// badge overlapping its corner, for a screen's lead image.
class ShapeIllustration extends StatelessWidget {
  const ShapeIllustration({
    super.key,
    required this.icon,
    this.badge,
    this.size = Sizes.illustration,
  });

  final IconData icon;

  /// A second, smaller icon on the corner, for what goes with the main one.
  final IconData? badge;
  final double size;

  /// The "cookie" shape: a circle with soft, rounded scallops.
  static const _cookie = StarBorder(
    points: 9,
    innerRadiusRatio: 0.84,
    // Rounded points and valleys together may add up to at most 1.
    pointRounding: 0.6,
    valleyRounding: 0.4,
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final badgeSize = size * 0.42;
    final badge = this.badge;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          DecoratedBox(
            decoration: ShapeDecoration(
              color: scheme.primaryContainer,
              shape: _cookie,
            ),
            child: Center(
              child: Icon(
                icon,
                size: size * 0.45,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          if (badge != null)
            Positioned(
              right: -badgeSize * 0.12,
              bottom: -badgeSize * 0.12,
              child: Container(
                width: badgeSize,
                height: badgeSize,
                decoration: ShapeDecoration(
                  color: scheme.tertiaryContainer,
                  // A ring in the surface colour sets the badge apart.
                  shape: CircleBorder(
                    side: BorderSide(color: scheme.surface, width: 3),
                  ),
                ),
                child: Icon(
                  badge,
                  size: badgeSize * 0.5,
                  color: scheme.onTertiaryContainer,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
