import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/routes.dart';
import '../../state/infrastructure.dart';
import '../../state/session_state.dart';
import '../../state/settings_state.dart';
import '../../ui/ui.dart';
import 'widgets/vehicle_card.dart';

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
    final homeVehicle = settings.mostRecentVehicle;

    if (vehicles.isEmpty) {
      return AppPage(
        title: 'Vehicles',
        children: [
          const SizedBox(height: Insets.xxl * 3),
          EmptyState(
            icon: Symbols.directions_car_rounded,
            title: 'No vehicles yet',
            message:
                'Add your car and the OBD-II adapter plugged into it. It '
                'takes about two minutes.',
            actionLabel: 'Add vehicle',
            actionIcon: Symbols.add_rounded,
            onAction: () => context.push(Routes.addVehicle),
            footnote: 'Any ELM327-compatible Bluetooth adapter works.',
          ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.addVehicle),
        icon: const Icon(Symbols.add_rounded),
        label: const Text('Add vehicle'),
      ),
      children: [
        for (final vehicle in vehicles) ...[
          VehicleCard(
            vehicle: vehicle,
            now: now,
            badge: badgeFor(vehicle.id),
            onTap: () => context.push(Routes.vehicle(vehicle.id)),
          ),
          const SizedBox(height: Insets.m),
        ],
        if (vehicles.length == 1)
          const InfoNote(
            text: TextSpan(
              text:
                  'Use Pitwall in more than one car? Add each one with its own '
                  'adapter. Home follows whichever car connected last.',
            ),
          ),
      ],
    );
  }
}
