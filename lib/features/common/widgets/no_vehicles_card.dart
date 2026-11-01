import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../../ui/ui.dart';

/// What Home and Vehicles show before any vehicle is added: what Pitwall
/// needs, the steps to get there, and the way in.
class NoVehiclesCard extends StatelessWidget {
  const NoVehiclesCard({super.key, required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ContentCard(
      padding: const EdgeInsets.all(Insets.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShapeIllustration(
            icon: Symbols.directions_car_rounded,
            badge: Symbols.bluetooth_rounded,
          ),
          const SizedBox(height: Insets.xl),
          Text('No vehicles yet', style: theme.textTheme.headlineSmall),
          const SizedBox(height: Insets.xs),
          Text(
            'Pitwall reads your car through an OBD-II adapter. Setting one '
            'up takes about two minutes.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Insets.xl),
          const NumberedSteps(
            steps: [
              NumberedStep(
                'Plug the adapter into the car\'s OBD-II port',
                detail: 'Any ELM327-compatible Bluetooth adapter works.',
              ),
              NumberedStep('Pair it in your phone\'s Bluetooth settings'),
              NumberedStep('Add it here'),
            ],
          ),
          const SizedBox(height: Insets.xl),
          SizedBox(
            width: double.infinity,
            child: GlassButton(
              onPressed: onAdd,
              icon: const Icon(Symbols.add_rounded),
              child: const Text('Add vehicle'),
            ),
          ),
        ],
      ),
    );
  }
}
