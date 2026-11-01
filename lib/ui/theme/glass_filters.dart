import 'dart:ui' show ColorFilter, ImageFilter;

/// The filters frosted surfaces apply to what's behind them.
abstract final class GlassFilters {
  /// Cards: a strong blur, since the page glows behind them are soft anyway.
  static final card = ImageFilter.blur(sigmaX: 24, sigmaY: 24);

  /// Bars over scrolling content, as platform materials do it: a lighter
  /// blur, so shapes passing underneath stay faintly visible, and a
  /// saturation boost, so their colours come through instead of greying.
  static final bar = ImageFilter.compose(
    outer: _saturate(1.8),
    inner: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
  );

  static ColorFilter _saturate(double s) {
    // Luminance weights (Rec. 709), as in the CSS saturate() filter.
    const r = 0.2126, g = 0.7152, b = 0.0722;
    return ColorFilter.matrix([
      r + (1 - r) * s, g - g * s, b - b * s, 0, 0, //
      r - r * s, g + (1 - g) * s, b - b * s, 0, 0, //
      r - r * s, g - g * s, b + (1 - b) * s, 0, 0, //
      0, 0, 0, 1, 0,
    ]);
  }
}
