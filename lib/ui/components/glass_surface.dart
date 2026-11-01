import 'package:material_ui/material_ui.dart';

import '../theme/glass_colors.dart';
import '../theme/glass_filters.dart';
import '../theme/tokens.dart';

/// A frosted card surface: blurs what's behind it, with a translucent fill
/// and a light edge. Every card in the app is built on it.
///
/// Inside a `PageBackdrop`, all surfaces on the page share one blur pass.
/// It's a [Material], so ink effects of rows inside show on it.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = Corners.extraLargeRadius,
    this.color,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// A tinted fill instead of the neutral one, e.g. for a running state.
  /// Keep it translucent, or there's nothing to see through.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter.grouped(
        // Shared by all cards: grouped blurs must use the same filter.
        filter: GlassFilters.card,
        child: Material(
          color: color ?? glass.fill,
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius,
            side: BorderSide(color: glass.edge),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
    );
  }
}
