import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'glass_surface.dart';

/// One block of content on the card surface: a form, a status, a summary.
/// For lists of rows, use `RowGroup`.
class ContentCard extends StatelessWidget {
  const ContentCard({
    super.key,
    required this.child,
    this.padding = Insets.card,
    this.dashed = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;

  /// A dashed border, for an empty slot inviting an action.
  final bool dashed;

  /// Makes the whole card one tap target, such as an "Add" slot.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final padded = Padding(padding: padding, child: child);
    final content = onTap == null
        ? padded
        : InkWell(onTap: onTap, child: padded);
    if (dashed) {
      return CustomPaint(
        foregroundPainter: _DashedBorderPainter(
          color: Theme.of(context).colorScheme.outline,
        ),
        // No fill of its own; a surface only for the tap ripple to show on.
        child: Material(
          type: MaterialType.transparency,
          shape: const RoundedRectangleBorder(
            borderRadius: Corners.extraLargeRadius,
          ),
          clipBehavior: Clip.antiAlias,
          child: content,
        ),
      );
    }
    return GlassSurface(child: content);
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  static const _dash = 6.0;
  static const _gap = 4.0;

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final outline = Path()
      ..addRRect(
        Corners.extraLargeRadius.toRRect(Offset.zero & size).deflate(0.5),
      );
    for (final metric in outline.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(metric.extractPath(d, d + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
