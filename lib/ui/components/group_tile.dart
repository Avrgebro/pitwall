import 'package:material_ui/material_ui.dart';

import '../theme/status_colors.dart';
import '../theme/tokens.dart';
import 'app_row.dart';

/// The common [AppRow]: an accent icon, a title, a one-line subtitle, and
/// a chevron when it opens a page. For a row that does something in place,
/// such as deleting, use [GroupTile.action], which has no chevron.
class GroupTile extends StatelessWidget {
  /// A row that opens a page on tap, or shows [trailing] instead of the
  /// chevron.
  const GroupTile({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    this.subtitleTag,
    this.subtitleTone,
    this.trailing,
    this.onTap,
  }) : tone = null,
       _opensPage = true;

  /// A row that acts in place: no chevron. [tone] colours it, e.g. error
  /// for "Delete vehicle".
  const GroupTile.action({
    super.key,
    required this.title,
    required VoidCallback this.onTap,
    this.icon,
    this.subtitle,
    this.subtitleTag,
    this.subtitleTone,
    this.tone,
  }) : trailing = null,
       _opensPage = false;

  final String title;
  final IconData? icon;
  final String? subtitle;

  /// A small label right after the subtitle, such as a [Tag], for a fact
  /// about what the subtitle names.
  final Widget? subtitleTag;

  /// Colours the subtitle, e.g. error for "1 needs fixing".
  final StatusTone? subtitleTone;
  final Widget? trailing;
  final VoidCallback? onTap;
  final StatusTone? tone;
  final bool _opensPage;

  @override
  Widget build(BuildContext context) => AppRow(
    title: title,
    tone: tone,
    leading: icon == null ? null : Icon(icon),
    subtitle: switch ((subtitle, subtitleTag)) {
      (null, _) => null,
      (final text?, null) => Text(text),
      (final text?, final tag?) => Row(
        children: [
          Flexible(child: Text(text)),
          const SizedBox(width: Insets.s),
          tag,
        ],
      ),
    },
    subtitleTone: subtitleTone,
    trailing: trailing,
    opensPage: _opensPage && onTap != null && trailing == null,
    onTap: onTap,
  );
}
