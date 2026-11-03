import 'package:material_ui/material_ui.dart';

import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import 'line_icon.dart';

/// Monospace text on a soft background: payload samples, raw traffic.
class CodeBlock extends StatelessWidget {
  const CodeBlock({super.key, required this.child});

  /// Usually a [Text] or [SelectableText]; monospace is applied.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: Insets.card,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: Corners.largeRadius,
      ),
      child: DefaultTextStyle.merge(
        style: theme.textTheme.mono.copyWith(height: 1.6),
        child: child,
      ),
    );
  }
}

/// An icon, a label and its value, for summaries.
class SummaryRow extends StatelessWidget {
  /// The value on the right of the label.
  const SummaryRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  }) : caption = null,
       stacked = false;

  /// The value under the label, for long values, with an optional hint
  /// under it.
  const SummaryRow.stacked({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
    this.valueColor,
  }) : stacked = true;

  final IconData icon;
  final String label;
  final String value;
  final String? caption;
  final Color? valueColor;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final valueText = Text(
      value,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: valueColor ?? theme.colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    );
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(color: muted);
    final labelText = Text(label, style: labelStyle);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LineIcon(
            icon,
            style: labelStyle,
            size: Sizes.iconSmall,
            color: muted,
          ),
          const SizedBox(width: Insets.l),
          Expanded(
            child: stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      labelText,
                      valueText,
                      if (caption != null)
                        Text(
                          caption!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: labelText),
                      valueText,
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
