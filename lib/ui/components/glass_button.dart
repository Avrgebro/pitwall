import 'package:material_ui/material_ui.dart';

import '../theme/glass_colors.dart';
import '../theme/glass_filters.dart';
import '../theme/status_colors.dart';

/// A filled button made of tinted glass, for actions that float over
/// scrolling content. Blurs what passes behind it, like the bars, so its
/// label keeps its contrast.
///
/// The default is the main action, tinted with the accent colour;
/// [GlassButton.neutral] is for the actions beside it.
class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
  }) : _tinted = true;

  const GlassButton.neutral({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
  }) : _tinted = false;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final Widget child;

  /// Shown before the label.
  final Widget? icon;
  final bool _tinted;

  static const _shape = StadiumBorder();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glass = context.glass;
    // Tinted as a card in the active tone is.
    final active = context.tone(StatusTone.active);
    final style = FilledButton.styleFrom(
      shape: _shape,
      backgroundColor: _tinted
          ? active.container.withValues(alpha: glass.tintOpacity)
          : glass.barFill,
      foregroundColor: _tinted ? active.onContainer : scheme.onSurface,
      disabledBackgroundColor: glass.barFill,
      disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
      side: BorderSide(color: glass.edge),
    );
    final icon = this.icon;
    return ClipPath(
      clipper: const ShapeBorderClipper(shape: _shape),
      child: BackdropFilter(
        filter: GlassFilters.bar,
        child: icon == null
            ? FilledButton(onPressed: onPressed, style: style, child: child)
            : FilledButton.icon(
                onPressed: onPressed,
                style: style,
                icon: icon,
                label: child,
              ),
      ),
    );
  }
}
