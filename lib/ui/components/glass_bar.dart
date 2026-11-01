import 'package:material_ui/material_ui.dart';

import '../theme/glass_colors.dart';
import '../theme/glass_filters.dart';
import '../theme/tokens.dart';

/// A frosted bar over the bottom of scrolling content, for an input bar or
/// a row of controls. Rounded on top, mirroring the top bar, and running
/// down behind the system navigation bar, which it keeps its content clear
/// of.
class GlassBar extends StatelessWidget {
  const GlassBar({super.key, required this.child});

  final Widget child;

  static const _shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(
      top: Radius.circular(Corners.extraLarge),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return ClipPath(
      clipper: const ShapeBorderClipper(shape: _shape),
      child: BackdropFilter(
        filter: GlassFilters.bar,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: glass.barFill,
            shape: _shape.copyWith(side: BorderSide(color: glass.edge)),
          ),
          child: SafeArea(top: false, child: child),
        ),
      ),
    );
  }
}
