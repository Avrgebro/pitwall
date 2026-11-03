import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'glass_surface.dart';

/// Rows shown as separate segments, a few pixels apart: large corners on
/// the outside of the group, small ones where segments meet. Each row reads
/// as its own tappable object while the group still reads as one.
class RowGroup extends StatelessWidget {
  const RowGroup({super.key, required this.children});

  final List<Widget> children;

  static const _gap = segmentGap;
  static const _outer = Radius.circular(Corners.extraLarge);
  static const _inner = Radius.circular(Corners.segment);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < children.length; i++)
        _segment(i, children.length, children[i]),
    ],
  );

  /// Row [index] of [count] in its segment, spaced from the one before.
  static Widget _segment(int index, int count, Widget child) {
    final borderRadius = BorderRadius.vertical(
      top: index == 0 ? _outer : _inner,
      bottom: index == count - 1 ? _outer : _inner,
    );
    return Padding(
      padding: EdgeInsets.only(top: index == 0 ? 0 : _gap),
      child: GlassSurface(
        borderRadius: borderRadius,
        child: RowSegment(borderRadius: borderRadius, child: child),
      ),
    );
  }
}

/// A [RowGroup] for long lists, as a sliver: only the rows on screen are
/// built. Use it in `AppPage.slivers`.
class SliverRowGroup extends StatelessWidget {
  const SliverRowGroup({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) => SliverList.builder(
    itemCount: itemCount,
    itemBuilder: (context, index) =>
        RowGroup._segment(index, itemCount, itemBuilder(context, index)),
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
