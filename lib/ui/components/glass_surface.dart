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
  /// problem. The theme inside then has the tone's text colours as
  /// `onSurface` and `onSurfaceVariant`, so whatever sits on it reads right.
  final StatusTone? tone;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final tone = this.tone;
    final colors = tone == null ? null : context.tone(tone);
    final surface = Material(
      color: colors == null ? glass.fill : glass.tint(colors),
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: glass.edge),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter.grouped(
        // Shared by all cards: grouped blurs must use the same filter.
        filter: GlassFilters.card,
        // The Material inside the tint, so the text and icon colours it
        // sets come from it too.
        child: colors == null ? surface : _tinted(context, colors, surface),
      ),
    );
  }

  /// The one source of the tint: the colours, text styles and icons of the
  /// theme inside, which whatever sits on the glass reads.
  static Widget _tinted(BuildContext context, ToneColors colors, Widget child) {
    final theme = Theme.of(context);
    final strong = colors.onContainer;
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          onSurface: strong,
          onSurfaceVariant: strong.withValues(alpha: 0.75),
        ),
        // The text styles took their colour from onSurface when the theme
        // was made, so they're tinted too.
        textTheme: theme.textTheme.apply(
          bodyColor: strong,
          displayColor: strong,
        ),
        iconTheme: theme.iconTheme.copyWith(color: strong),
      ),
      child: child,
    );
  }
}
