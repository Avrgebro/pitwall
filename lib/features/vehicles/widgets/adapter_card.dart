import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/vehicles/vehicle.dart';
import '../../../ui/ui.dart';

/// The vehicle's adapter: name, connection type and address.
class AdapterCard extends StatelessWidget {
  const AdapterCard({super.key, required this.vehicle, required this.onChange});

  final Vehicle vehicle;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final address = vehicle.adapterAddress;
    return GroupCard(
      padding: Insets.card,
      children: [
        Row(
          children: [
            const IconBadge(
              icon: Symbols.bluetooth_rounded,
              tone: StatusTone.neutral,
              shape: BoxShape.circle,
            ),
            const SizedBox(width: Insets.l),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          vehicle.adapterName ?? 'No adapter chosen',
                          style: theme.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (address != null) ...[
                        const SizedBox(width: Insets.s),
                        TagLabel(switch (vehicle.adapterType) {
                          AdapterType.classic => 'Classic',
                          AdapterType.ble => 'Bluetooth LE',
                        }),
                      ],
                    ],
                  ),
                  if (address != null)
                    Text(
                      address,
                      style: theme.textTheme.mono.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: onChange,
              child: Text(address == null ? 'Choose' : 'Change'),
            ),
          ],
        ),
      ],
    );
  }
}
