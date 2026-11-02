import 'package:material_ui/material_ui.dart';

import '../theme/text_styles.dart';
import '../theme/tokens.dart';

/// One value to show in a [ValueGrid].
@immutable
class ValueTileData {
  const ValueTileData({required this.label, required this.value, this.unit});

  final String label;

  /// The formatted value, or null if the car didn't report it.
  final String? value;
  final String? unit;
}

/// A value with its label and unit. Values are the biggest type on screen;
/// labels and units step back.
class ValueTile extends StatelessWidget {
  const ValueTile({super.key, required this.data, this.wide = false});

  final ValueTileData data;

  /// Full width, with the label beside the value instead of above it.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = Text(
      data.label,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.l,
        vertical: Insets.mPlus,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: Corners.largeRadius,
      ),
      child: wide
          ? Row(
              children: [
                Expanded(child: label),
                _Value(data: data),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                label,
                const SizedBox(height: Insets.xs),
                _Value(data: data),
              ],
            ),
    );
  }
}

class _Value extends StatelessWidget {
  const _Value({required this.data});

  final ValueTileData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final value = data.value;
    if (value == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('—', style: theme.textTheme.value.copyWith(color: muted)),
          Text(
            'Car didn\'t report this',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      );
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: value,
            style: theme.textTheme.value.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          if (data.unit case final unit? when unit.isNotEmpty)
            TextSpan(
              text: ' $unit',
              style: theme.textTheme.valueUnit.copyWith(color: muted),
            ),
        ],
      ),
    );
  }
}

/// Values in two columns. With an odd count, the last one spans the full
/// width, so the grid never ends with a gap.
class ValueGrid extends StatelessWidget {
  const ValueGrid({super.key, required this.values});

  final List<ValueTileData> values;

  @override
  Widget build(BuildContext context) {
    final pairs = values.length ~/ 2;
    final rows = <Widget>[
      for (var i = 0; i < pairs; i++)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: ValueTile(data: values[i * 2])),
              const SizedBox(width: Insets.s),
              Expanded(child: ValueTile(data: values[i * 2 + 1])),
            ],
          ),
        ),
      if (values.length.isOdd) ValueTile(data: values.last, wide: true),
    ];
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: Insets.s),
          rows[i],
        ],
      ],
    );
  }
}
