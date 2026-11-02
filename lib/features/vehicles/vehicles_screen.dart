import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/routes.dart';
import '../../state/focus_state.dart';
import '../../state/infrastructure.dart';
import '../../state/session_state.dart';
import '../../state/settings_state.dart';
import '../../ui/ui.dart';
import 'widgets/no_vehicles_card.dart';
import 'widgets/vehicle_row.dart';

class VehiclesScreen extends ConsumerWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider).value;
    if (settings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final session = ref.watch(sessionProvider);
    final now = ref.watch(nowProvider);
    final vehicles = settings.vehicles;
    final homeVehicle = ref.watch(focusedVehicleProvider);

    if (vehicles.isEmpty) {
      return AppPage(
        title: 'Vehicles',
        children: [
          NoVehiclesCard(onAdd: () => context.push(Routes.addVehicle)),
        ],
      );
    }

    VehicleBadge badgeFor(String id) {
      if (session.isConnected && session.vehicleId == id) {
        return VehicleBadge.connected;
      }
      if (vehicles.length > 1 && homeVehicle?.id == id) {
        return VehicleBadge.onHome;
      }
      return VehicleBadge.none;
    }

    return AppPage(
      title: 'Vehicles',
      children: [
        RowGroup(
          children: [
            for (final vehicle in vehicles)
              VehicleRow(
                vehicle: vehicle,
                now: now,
                badge: badgeFor(vehicle.id),
                onTap: () => context.push(Routes.vehicle(vehicle.id)),
              ),
          ],
        ),
        const SizedBox(height: Insets.m),
        _AddVehicleCard(onTap: () => context.push(Routes.addVehicle)),
        if (vehicles.length == 1)
          const InfoNote(
            text: TextSpan(
              text:
                  'Use Pitwall in more than one car? Add each one with its own '
                  'adapter. Home follows whichever car connected last, and '
                  'you can switch between them there.',
            ),
          ),
      ],
    );
  }
}

/// An empty slot at the end of the list, for adding another vehicle.
class _AddVehicleCard extends StatelessWidget {
  const _AddVehicleCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return ContentCard(
      dashed: true,
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Symbols.add_rounded, color: color),
          const SizedBox(width: Insets.s),
          Text(
            'Add vehicle',
            style: theme.textTheme.titleMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
