import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'glass_surface.dart';

/// Rows shown as separate segments, a few pixels apart: large corners on
/// the outside of the group, small ones where segments meet. Each row reads
/// as its own tappable object while the group still reads as one.
class RowGroup extends StatelessWidget {
  const RowGroup({super.key, required this.children});

  final List<Widget> children;

  static const _gap = 3.0;
  static const _outer = Radius.circular(Corners.extraLarge);
  static const _inner = Radius.circular(Corners.small - 2);

  @override
  Widget build(BuildContext context) {
    final last = children.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i <= last; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : _gap),
            child: _segment(
              BorderRadius.vertical(
                top: i == 0 ? _outer : _inner,
                bottom: i == last ? _outer : _inner,
              ),
              children[i],
            ),
          ),
      ],
    );
  }

  Widget _segment(BorderRadius borderRadius, Widget child) => GlassSurface(
    borderRadius: borderRadius,
    child: RowSegment(borderRadius: borderRadius, child: child),
  );
}

/// The shape of the segment a row sits in, for rows that draw on its
/// outline, such as a selected option.
class RowSegment extends InheritedWidget {
  const RowSegment({
    super.key,
    required this.borderRadius,
    required super.child,
  });

  final BorderRadius borderRadius;

  /// The corners of the enclosing segment, or none outside a `RowGroup`.
  static BorderRadius borderRadiusOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RowSegment>()?.borderRadius ??
      BorderRadius.zero;

  @override
  bool updateShouldNotify(RowSegment oldWidget) =>
      borderRadius != oldWidget.borderRadius;
}
