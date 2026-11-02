import 'package:material_ui/material_ui.dart';

import '../theme/glass_colors.dart';
import '../theme/glass_filters.dart';
import '../theme/status_colors.dart';
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
    this.tone,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// Tints the glass in the tone's colour, e.g. for a running state or a
  /// problem, and sets the text colours inside to match; see [GlassInk].
  final StatusTone? tone;

  /// How much of a tint shows; the rest is the blurred page behind.
  static const _tintOpacity = 0.7;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final tone = this.tone;
    final colors = tone == null ? null : context.tone(tone);
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter.grouped(
        // Shared by all cards: grouped blurs must use the same filter.
        filter: GlassFilters.card,
        child: Material(
          color:
              colors?.container.withValues(alpha: _tintOpacity) ?? glass.fill,
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius,
            side: BorderSide(color: glass.edge),
          ),
          clipBehavior: Clip.antiAlias,
          child: colors == null
              ? child
              : GlassInk(
                  strong: colors.onContainer,
                  muted: colors.onContainer.withValues(alpha: 0.75),
                  child: child,
                ),
        ),
      ),
    );
  }
}

/// The text colours on the surface a widget sits on: [strong] for titles
/// and values, [muted] for labels and explanations. A tinted
/// [GlassSurface] sets them; elsewhere they're the theme's.
class GlassInk extends InheritedWidget {
  const GlassInk({
    super.key,
    required this.strong,
    required this.muted,
    required super.child,
  });

  final Color strong;
  final Color muted;

  static ({Color strong, Color muted}) of(BuildContext context) {
    final ink = context.dependOnInheritedWidgetOfExactType<GlassInk>();
    if (ink != null) return (strong: ink.strong, muted: ink.muted);
    final scheme = Theme.of(context).colorScheme;
    return (strong: scheme.onSurface, muted: scheme.onSurfaceVariant);
  }

  @override
  bool updateShouldNotify(GlassInk oldWidget) =>
      strong != oldWidget.strong || muted != oldWidget.muted;
}
