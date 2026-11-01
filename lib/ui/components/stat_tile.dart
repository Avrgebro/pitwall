import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// A small label above a value ("Last sent / 40 s ago").
class LabeledValue extends StatelessWidget {
  const LabeledValue({
    super.key,
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;

  /// Text colour; defaults to the surrounding text colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.bodySmall?.copyWith(color: color)),
        Text(
          value,
          style: text.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// [LabeledValue]s side by side in equal columns.
class LabeledValueRow extends StatelessWidget {
  const LabeledValueRow({super.key, required this.items, this.color});

  final List<({String label, String value})> items;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final item in items)
        Expanded(
          child: LabeledValue(
            label: item.label,
            value: item.value,
            color: color,
          ),
        ),
    ],
  );
}

/// An icon, label and value on a soft background, used side by side
/// (Adapter · Car · Trip).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(Insets.m),
    decoration: BoxDecoration(
      color: background,
      borderRadius: Corners.largeRadius,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: Sizes.iconSmall, color: foreground),
        const SizedBox(height: Insets.s),
        LabeledValue(label: label, value: value, color: foreground),
      ],
    ),
  );
}
