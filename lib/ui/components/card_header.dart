import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// A card's heading: an icon badge, a title and an optional line under it,
/// and an optional widget at the end, such as a button.
class CardHeader extends StatelessWidget {
  const CardHeader({
    super.key,
    required this.badge,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  /// Usually an `IconBadge`.
  final Widget badge;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final subtitle = this.subtitle;
    final trailing = this.trailing;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        badge,
        const SizedBox(width: Insets.l),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: Insets.s), trailing],
      ],
    );
  }
}
