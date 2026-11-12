import 'package:material_ui/material_ui.dart';

import '../theme/status_colors.dart';
import '../theme/tokens.dart';
import 'status_chip.dart';

/// A small label on a row, such as how an adapter connects: smaller and
/// squarer than a [StatusChip], which shows a state rather than a fact.
class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, this.tone = StatusTone.neutral});

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.tone(tone);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.xsPlus,
        vertical: Insets.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.container,
        borderRadius: const BorderRadius.all(Radius.circular(Corners.tag)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.onContainer,
          fontSize: 10,
          height: 1.3,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
