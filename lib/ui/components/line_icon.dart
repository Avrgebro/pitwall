import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:material_ui/material_ui.dart';

/// Centres [child] on the first line of the text beside it, so it lines up
/// whether the text runs to one line or several.
///
/// Place it in a `Row` with `CrossAxisAlignment.start`. Baseline alignment
/// doesn't work for icons and badges: their baseline, if any, is their
/// bottom edge, so they would sit above the text.
class FirstLineCentered extends StatelessWidget {
  const FirstLineCentered({
    super.key,
    required this.style,
    required this.child,
  });

  /// The style of the text [child] sits beside.
  final TextStyle? style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final line = TextPainter(
      text: TextSpan(text: ' ', style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final height = line.height;
    line.dispose();
    // As tall as the line; a taller child spills evenly above and below.
    return SizedBox(
      height: height,
      child: OverflowBox(
        maxHeight: double.infinity,
        fit: OverflowBoxFit.deferToChild,
        child: child,
      ),
    );
  }
}

/// An icon centred on the first line of the text beside it; see
/// [FirstLineCentered].
class LineIcon extends StatelessWidget {
  const LineIcon(
    this.icon, {
    super.key,
    required this.style,
    this.size,
    this.color,
  });

  final IconData icon;

  /// The style of the text the icon sits beside.
  final TextStyle? style;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) => FirstLineCentered(
    style: style,
    child: Icon(icon, size: size, color: color),
  );
}
