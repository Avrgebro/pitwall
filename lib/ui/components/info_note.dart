import 'package:material_ui/material_ui.dart';

import '../theme/status_colors.dart';
import '../theme/tokens.dart';
import 'line_icon.dart';

/// A small icon and a line of text beside it, the icon centred on the
/// text's first line: help under content, a field's helper, a short status.
class InfoNote extends StatelessWidget {
  const InfoNote({
    super.key,
    required this.text,
    this.icon = Icons.info_outline,
    this.tone,
    this.dense = false,
    this.padding = const EdgeInsets.symmetric(
      horizontal: Insets.xs,
      vertical: Insets.m,
    ),
  });

  /// The text, as a span so parts can be styled or linked.
  final InlineSpan text;
  final IconData icon;

  /// Colours it in a status's accent, e.g. error for a failure; muted
  /// without one.
  final StatusTone? tone;

  /// The smaller size of a form field's helper text.
  final bool dense;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = this.tone;
    final color = tone == null
        ? theme.colorScheme.onSurfaceVariant
        : context.tone(tone).accent;
    final style =
        (dense ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)
            ?.copyWith(color: color);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LineIcon(
            icon,
            style: style,
            size: dense ? 14 : Sizes.iconSmall,
            color: color,
          ),
          SizedBox(width: dense ? Insets.xsPlus : Insets.m),
          Expanded(child: Text.rich(text, style: style)),
        ],
      ),
    );
  }
}
