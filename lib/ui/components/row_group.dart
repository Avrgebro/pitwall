import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final last = children.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i <= last; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : _gap),
            child: Material(
              color: scheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  top: i == 0 ? _outer : _inner,
                  bottom: i == last ? _outer : _inner,
                ),
                side: BorderSide(color: scheme.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: children[i],
            ),
          ),
      ],
    );
  }
}
