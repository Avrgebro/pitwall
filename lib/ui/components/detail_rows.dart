import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'small_parts.dart';

/// A card's details as rows on a soft panel: icon, label, and the value at
/// the full width of the card, so nothing gets squeezed.
class DetailRows extends StatelessWidget {
  const DetailRows({
    super.key,
    required this.rows,
    required this.background,
    this.color,
  });

  final List<({IconData icon, String label, String value})> rows;

  /// The panel behind the rows; a faint layer over the card.
  final Color background;

  /// The text colour on a tinted card; see [SummaryRow.color].
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: Insets.l,
      vertical: Insets.xs,
    ),
    decoration: BoxDecoration(
      color: background,
      borderRadius: Corners.largeRadius,
    ),
    child: Column(
      children: [
        for (final row in rows)
          SummaryRow(
            icon: row.icon,
            label: row.label,
            value: row.value,
            color: color,
          ),
      ],
    ),
  );
}
