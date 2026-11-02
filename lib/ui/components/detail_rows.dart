import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'small_parts.dart';

/// A card's details as rows on a soft panel: icon, label, and the value at
/// the full width of the card, so nothing gets squeezed. Takes its text
/// colours from the theme, which a tinted `GlassSurface` sets.
class DetailRows extends StatelessWidget {
  const DetailRows({super.key, required this.rows});

  final List<({IconData icon, String label, String value})> rows;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: Insets.l,
      vertical: Insets.xs,
    ),
    decoration: BoxDecoration(
      // A faint layer over the card, neutral or tinted.
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.4),
      borderRadius: Corners.largeRadius,
    ),
    child: Column(
      children: [
        for (final row in rows)
          SummaryRow(icon: row.icon, label: row.label, value: row.value),
      ],
    ),
  );
}
