import 'package:material_ui/material_ui.dart';

import '../theme/glass_colors.dart';

/// The background behind every page: the surface colour with two soft
/// glows in the theme's accents. Frosted cards blur it, which is what
/// makes them read as glass.
///
/// Cards inside share one blur pass through the [BackdropGroup] this
/// provides, so many cards on a page cost about as much as one.
class PageBackdrop extends StatelessWidget {
  const PageBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _Glow(
            color: glass.glow,
            center: const Alignment(-0.9, -0.95),
            radius: 1.1,
          ),
          _Glow(
            color: glass.secondGlow,
            center: const Alignment(1, 0.2),
            radius: 0.9,
          ),
          BackdropGroup(child: child),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({
    required this.color,
    required this.center,
    required this.radius,
  });

  final Color color;
  final Alignment center;
  final double radius;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: center,
        radius: radius,
        colors: [color, color.withValues(alpha: 0)],
      ),
    ),
  );
}
