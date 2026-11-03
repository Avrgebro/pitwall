import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// A row with a part that opens under it while [open]. The whole of it is
/// one tap target, so its ripple fills the opened part too; fields inside
/// take their own taps.
class ExpandableRow extends StatelessWidget {
  const ExpandableRow({
    super.key,
    required this.row,
    required this.open,
    required this.child,
    this.onTap,
  });

  final Widget row;
  final bool open;

  /// What opens. Padded like a content card, so fields in it line up with
  /// fields in cards around it.
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: open
              ? Padding(padding: Insets.card.copyWith(top: 0), child: child)
              : const SizedBox(width: double.infinity),
        ),
      ],
    ),
  );
}
