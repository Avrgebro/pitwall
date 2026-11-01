import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/vehicles/vehicle.dart';
import '../../../ui/ui.dart';

enum VehicleBadge { none, connected, onHome }

/// A vehicle in the list: name, adapter, profile and when it was last seen.
class VehicleCard extends StatelessWidget {
  const VehicleCard({
    super.key,
    required this.vehicle,
    required this.now,
    required this.onTap,
    this.badge = VehicleBadge.none,
  });

  final Vehicle vehicle;
  final DateTime now;
  final VehicleBadge badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlighted = badge != VehicleBadge.none;
    final lastSeen = vehicle.lastSeen;
    return GlassSurface(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: Insets.card,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(
                icon: Symbols.directions_car_rounded,
                tone: highlighted ? StatusTone.active : StatusTone.neutral,
                size: Sizes.badge + 8,
              ),
              const SizedBox(width: Insets.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            vehicle.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        switch (badge) {
                          VehicleBadge.connected => const StatusChip(
                            label: 'Connected',
                            tone: StatusTone.active,
                            emphasis: ChipEmphasis.filled,
                            dot: true,
                            dense: true,
                          ),
                          VehicleBadge.onHome => const StatusChip(
                            label: 'On Home',
                            dense: true,
                          ),
                          VehicleBadge.none => const SizedBox.shrink(),
                        },
                      ],
                    ),
                    const SizedBox(height: Insets.xs),
                    IconText(
                      icon: Symbols.bluetooth_rounded,
                      text: vehicle.adapterName ?? 'No adapter chosen',
                    ),
                    IconText(
                      icon: vehicle.profileName == null
                          ? Symbols.tune_rounded
                          : Symbols.description_rounded,
                      text: switch ((vehicle.profileName, vehicle.modelYear)) {
                        (null, _) => 'Standard values only',
                        (_, final year?) => 'Vehicle profile · $year',
                        (_, null) => 'Vehicle profile · no model year',
                      },
                    ),
                    IconText(
                      icon: Symbols.schedule_rounded,
                      text: badge == VehicleBadge.connected
                          ? 'Seen just now'
                          : lastSeen == null
                          ? 'Not seen yet'
                          : 'Last seen ${Formatters.ago(lastSeen, now)}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
