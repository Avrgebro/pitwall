import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'line_icon.dart';

/// A small icon and a line of help text, set apart from the content around
/// it.
class InfoNote extends StatelessWidget {
  const InfoNote({
    super.key,
    required this.text,
    this.icon = Icons.info_outline,
    this.padding = const EdgeInsets.symmetric(
      horizontal: Insets.xs,
      vertical: Insets.m,
    ),
  });

  /// The text, as a span so parts can be styled or linked.
  final InlineSpan text;
  final IconData icon;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    final style = theme.textTheme.bodyMedium?.copyWith(color: color);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LineIcon(icon, style: style, size: Sizes.iconSmall, color: color),
          const SizedBox(width: Insets.m),
          Expanded(child: Text.rich(text, style: style)),
        ],
      ),
    );
  }
}
