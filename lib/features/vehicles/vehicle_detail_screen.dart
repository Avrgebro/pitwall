import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/profiles/signal_set.dart';
import '../../core/readings/readings.dart';
import '../../core/vehicles/vehicle.dart';
import '../../state/settings_state.dart';
import '../../ui/ui.dart';
import '../common/profile_text.dart';
import '../common/trip_start_text.dart';

/// One vehicle's overview: a row per setting, each opening its own page.
class VehicleDetailScreen extends ConsumerWidget {
  const VehicleDetailScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicle = ref.watch(vehicleProvider(vehicleId));
    if (vehicle == null) {
      return const AppPage(
        title: 'Vehicle',
        children: [InfoNote(text: TextSpan(text: 'This vehicle was removed.'))],
      );
    }
    final profile = ref.watch(vehicleProfileProvider(vehicleId)).value;
    final options = valueOptions(profile, vehicle.modelYear);
    final selected = vehicle.selectedKeys ?? defaultKeys(options);
    final tripStart = TripStartText.summary(vehicle);

    return AppPage(
      title: vehicle.name,
      children: [
        const SectionHeader(
          'Vehicle',
          icon: Symbols.directions_car_rounded,
          padding: EdgeInsets.fromLTRB(Insets.xs, 0, Insets.xs, Insets.m),
        ),
        RowGroup(
          children: [
            GroupTile(
              icon: Symbols.badge_rounded,
              title: 'Name',
              subtitle: 'Sent as ${vehicle.deviceId}',
              onTap: () => context.push(Routes.vehicleName(vehicle.id)),
            ),
            GroupTile(
              icon: Symbols.bluetooth_rounded,
              title: 'Adapter',
              subtitle: _adapterSummary(vehicle),
              subtitleTone: vehicle.needs.contains(VehicleNeed.adapter)
                  ? StatusTone.error
                  : null,
              onTap: () => context.push(Routes.vehicleAdapter(vehicle.id)),
            ),
            GroupTile(
              icon: Symbols.bluetooth_drive_rounded,
              title: 'Trip start',
              subtitle: tripStart.text,
              subtitleTone: tripStart.problem ? StatusTone.error : null,
              onTap: () => context.push(Routes.vehicleTripStart(vehicle.id)),
            ),
          ],
        ),
        const SectionHeader('Data', icon: Symbols.database_rounded),
        RowGroup(
          children: [
            GroupTile(
              icon: Symbols.data_object_rounded,
              title: 'Vehicle profile',
              subtitle: _profileSummary(vehicle, profile),
              onTap: () => context.push(Routes.vehicleProfile(vehicle.id)),
            ),
            GroupTile(
              icon: Symbols.checklist_rounded,
              title: 'Values to send',
              subtitle:
                  '${selected.length} value${selected.length == 1 ? '' : 's'}',
              onTap: () => context.push(Routes.vehicleValues(vehicle.id)),
            ),
          ],
        ),
        const SizedBox(height: Insets.xxl),
        RowGroup(
          children: [
            GroupTile(
              icon: Symbols.delete_rounded,
              title: 'Delete vehicle',
              destructive: true,
              onTap: () => _delete(context, ref, vehicle),
            ),
          ],
        ),
      ],
    );
  }

  static String _adapterSummary(Vehicle vehicle) =>
      switch ((vehicle.adapterName, vehicle.adapterType)) {
        (null, _) => 'Not chosen yet',
        (final name?, AdapterType.classic) => '$name (Classic)',
        (final name?, AdapterType.ble) => '$name (Bluetooth LE)',
      };

  static String _profileSummary(Vehicle vehicle, SignalSet? profile) =>
      switch ((profile, vehicle.modelYear)) {
        (null, _) => 'Standard values only',
        (_, null) => 'OBDb profile: choose the model year',
        (final profile?, final year?) =>
          'OBDb profile: ${ProfileText.applies(profile, year)}',
      };

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Vehicle vehicle,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${vehicle.name}?'),
        content: const Text(
          'Its adapter, profile and chosen values are removed from this '
          'phone. Readings already sent stay where they are.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    context.pop();
    await ref.read(appSettingsProvider.notifier).deleteVehicle(vehicle.id);
  }
}
