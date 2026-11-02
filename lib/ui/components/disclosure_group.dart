import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'group_tile.dart';
import 'row_group.dart';

/// The row that shows or hides a longer list under it ("Show 12 more",
/// "Hide 12 devices"), with an arrow saying which. The list itself is the
/// caller's, so it can be built however suits it, even lazily: it shows
/// when [listShown].
class DisclosureGroup extends StatelessWidget {
  const DisclosureGroup({
    super.key,
    required this.open,
    required this.showLabel,
    required this.hideLabel,
    required this.onToggle,
    this.icon,
    this.subtitle,
    this.forcedOpen = false,
  });

  final bool open;
  final String showLabel;
  final String hideLabel;
  final VoidCallback onToggle;
  final IconData? icon;
  final String? subtitle;

  /// Keeps the list open with no row to close it, e.g. while filtering,
  /// so a match is never folded away.
  final bool forcedOpen;

  bool get listShown => forcedOpen || open;

  @override
  Widget build(BuildContext context) => forcedOpen
      ? const SizedBox.shrink()
      : Padding(
          // Apart from the list that opens under it.
          padding: EdgeInsets.only(bottom: open ? Insets.m : 0),
          child: RowGroup(
            children: [
              GroupTile(
                icon: icon,
                title: open ? hideLabel : showLabel,
                subtitle: subtitle,
                trailing: Icon(
                  open ? Icons.expand_less : Icons.expand_more,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onTap: onToggle,
              ),
            ],
          ),
        );
}
