import 'package:material_ui/material_ui.dart';

import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import 'line_icon.dart';

/// A small outlined label beside a name, such as "Bluetooth LE".
class TagLabel extends StatelessWidget {
  const TagLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.s - 2,
        vertical: Insets.xxs,
      ),
      decoration: BoxDecoration(
        borderRadius: Corners.smallRadius,
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Text(text, style: theme.textTheme.labelSmall),
    );
  }
}

/// A small icon and a line of text, for detail lines in list items.
class IconText extends StatelessWidget {
  const IconText({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: Sizes.iconSmall - 2, color: color),
        const SizedBox(width: Insets.s),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

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
        style: theme.textTheme.mono.copyWith(
          color: theme.colorScheme.onSurface,
          height: 1.6,
        ),
        child: child,
      ),
    );
  }
}

/// An icon, a label and a value on the right, for summaries.
class SummaryRow extends StatelessWidget {
  const SummaryRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
    this.valueColor,
    this.stacked = false,
  });

  final IconData icon;
  final String label;
  final String value;

  /// A hint under the value.
  final String? caption;
  final Color? valueColor;

  /// Value under the label instead of on the right, for long values.
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
