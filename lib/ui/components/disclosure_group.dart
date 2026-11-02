import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'group_tile.dart';
import 'row_group.dart';

/// The row that shows or hides a longer list under it ("Show 12 more",
/// "Hide 12 devices"), with an arrow saying which. The list itself is the
/// caller's, so it can be built however suits it, even lazily.
class DisclosureGroup extends StatelessWidget {
  const DisclosureGroup({
    super.key,
    required this.open,
    required this.showLabel,
    required this.hideLabel,
    required this.onToggle,
    this.icon,
    this.subtitle,
  });

  final bool open;
  final String showLabel;
  final String hideLabel;
  final VoidCallback onToggle;
  final IconData? icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
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
