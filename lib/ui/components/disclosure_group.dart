import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'disclosure.dart';
import 'group_tile.dart';
import 'row_group.dart';

/// The row that shows or hides a longer list under it ("Show 12 devices",
/// "Hide 12 devices"), with an arrow saying which. Nothing while the list
/// is [Disclosure.forced] open. The list itself is the caller's, so it can
/// be built however suits it, even lazily.
class DisclosureGroup extends StatelessWidget {
  const DisclosureGroup({
    super.key,
    required this.disclosure,
    required this.count,
    required this.noun,
    required this.onToggle,
    this.icon,
    this.subtitle,
  });

  final Disclosure disclosure;

  /// How many the list holds, and what they are, like `devices`.
  final int count;
  final String noun;

  final VoidCallback onToggle;
  final IconData? icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    if (!disclosure.showsToggle) return const SizedBox.shrink();
    final open = disclosure.open;
    return Padding(
      // Apart from the list that opens under it.
      padding: EdgeInsets.only(bottom: open ? Insets.m : 0),
      child: RowGroup(
        children: [
          GroupTile(
            icon: icon,
            title: '${open ? 'Hide' : 'Show'} $count $noun',
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
}
