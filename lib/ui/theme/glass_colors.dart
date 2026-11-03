import 'dart:ui' show lerpDouble;

import 'package:material_ui/material_ui.dart';

import 'status_colors.dart';

/// Colours for the frosted look: the soft glows behind pages and the
/// translucent fill and light edge of cards on top of them.
@immutable
class GlassColors extends ThemeExtension<GlassColors> {
  const GlassColors({
    required this.fill,
    required this.barFill,
    required this.tintOpacity,
    required this.panel,
    required this.edge,
    required this.glow,
    required this.secondGlow,
  });

  factory GlassColors.from(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    // Translucent enough to see the page through, opaque enough to read on.
    final tintOpacity = dark ? 0.6 : 0.65;
    return dark
        ? GlassColors(
            fill: scheme.surfaceContainerLow.withValues(alpha: 0.5),
            barFill: scheme.surfaceContainer.withValues(alpha: 0.5),
            tintOpacity: tintOpacity,
            panel: scheme.surface.withValues(alpha: 0.4),
            edge: Colors.white.withValues(alpha: 0.1),
            glow: scheme.primary.withValues(alpha: 0.34),
            secondGlow: scheme.tertiary.withValues(alpha: 0.24),
          )
        : GlassColors(
            fill: scheme.surfaceContainerLowest.withValues(alpha: 0.55),
            barFill: scheme.surfaceContainerLowest.withValues(alpha: 0.6),
            tintOpacity: tintOpacity,
            panel: scheme.surface.withValues(alpha: 0.4),
            edge: scheme.outlineVariant.withValues(alpha: 0.6),
            glow: scheme.primary.withValues(alpha: 0.26),
            secondGlow: scheme.tertiary.withValues(alpha: 0.2),
          );
  }

  /// Card background: lets the page glows show through, blurred.
  final Color fill;

  /// Background of bars over scrolling content: the top bar and the
  /// navigation bar.
  final Color barFill;

  /// How opaque a tone's container colour is on glass: tinted cards and
  /// the main floating action. The container colour, close to the
  /// background in brightness, keeps its text readable through the
  /// translucency.
  final double tintOpacity;

  /// A faint layer over a card, neutral or tinted, for panels and segments
  /// set into it.
  final Color panel;

  /// Glass tinted in a tone: its container colour at [tintOpacity].
  Color tint(ToneColors tone) => tone.container.withValues(alpha: tintOpacity);

  /// A thin edge that catches the light, outlining the card.
  final Color edge;

  /// The main glow behind pages, near the top.
  final Color glow;

  /// A quieter glow further down, so the frost isn't one flat colour.
  final Color secondGlow;

  @override
  GlassColors copyWith({
    Color? fill,
    Color? barFill,
    double? tintOpacity,
    Color? panel,
    Color? edge,
    Color? glow,
    Color? secondGlow,
  }) => GlassColors(
    fill: fill ?? this.fill,
    barFill: barFill ?? this.barFill,
    tintOpacity: tintOpacity ?? this.tintOpacity,
    panel: panel ?? this.panel,
    edge: edge ?? this.edge,
    glow: glow ?? this.glow,
    secondGlow: secondGlow ?? this.secondGlow,
  );

  @override
  GlassColors lerp(GlassColors? other, double t) {
    if (other == null) return this;
    return GlassColors(
      fill: Color.lerp(fill, other.fill, t)!,
      barFill: Color.lerp(barFill, other.barFill, t)!,
      tintOpacity: lerpDouble(tintOpacity, other.tintOpacity, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      edge: Color.lerp(edge, other.edge, t)!,
      glow: Color.lerp(glow, other.glow, t)!,
      secondGlow: Color.lerp(secondGlow, other.secondGlow, t)!,
    );
  }
}

extension GlassColorsContext on BuildContext {
  /// The frosted-surface colours of the current theme.
  GlassColors get glass => Theme.of(this).extension<GlassColors>()!;
}
