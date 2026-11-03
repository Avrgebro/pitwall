import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/profiles/stored_profile.dart';
import '../../core/readings/readings.dart';
import '../../core/vehicles/vehicle.dart';
import '../../state/settings_state.dart';
import '../../ui/ui.dart';
import '../common/profile_text.dart';
import '../common/vehicle_text.dart';
import '../common/trip_start_text.dart';
import 'widgets/vehicle_page.dart';

/// One vehicle's overview: a row per setting, each opening its own page.
class VehicleDetailScreen extends ConsumerWidget {
  const VehicleDetailScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => VehiclePage(
    vehicleId: vehicleId,
    title: 'Vehicle',
    builder: (context, values) => _page(context, ref, values),
  );

  Widget _page(BuildContext context, WidgetRef ref, VehicleValues values) {
    final vehicle = values.vehicle;
    final profile = _profileSummary(values);
    final selected = values.sent;
    final tripStart = TripStartText.summary(vehicle);

    return AppPage(
      title: vehicle.name,
      children: [
        const SectionHeader.icon(
          'Vehicle',
          icon: Symbols.directions_car_rounded,
          padding: SectionHeader.firstPadding,
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
        const SectionHeader.icon('Data', icon: Symbols.database_rounded),
        RowGroup(
          children: [
            GroupTile(
              icon: Symbols.data_object_rounded,
              title: 'Vehicle profile',
              subtitle: profile.text,
              subtitleTone: profile.problem ? StatusTone.error : null,
              onTap: () => context.push(Routes.vehicleProfile(vehicle.id)),
            ),
            GroupTile(
              icon: Symbols.checklist_rounded,
              title: 'Values to send',
              subtitle: ProfileText.values(selected.length),
              onTap: () => context.push(Routes.vehicleValues(vehicle.id)),
            ),
          ],
        ),
        const SizedBox(height: Insets.xxl),
        RowGroup(
          children: [
            GroupTile.action(
              icon: Symbols.delete_rounded,
              title: 'Delete vehicle',
              tone: StatusTone.error,
              onTap: () => _delete(context, ref, vehicle),
            ),
          ],
        ),
      ],
    );
  }

  static String _adapterSummary(Vehicle vehicle) =>
      switch (vehicle.adapterName) {
        null => 'Not chosen yet',
        final name => '$name (${vehicle.adapterType.label})',
      };

  static ({String text, bool problem}) _profileSummary(VehicleValues values) =>
      switch ((values.stored, values.profile)) {
        (UnreadableProfile(), _) => (
          text: 'OBDb profile can\'t be read',
          problem: true,
        ),
        (LoadedProfile(), final summary?) => (
          text: 'OBDb profile: ${ProfileText.forYear(summary)}',
          problem: false,
        ),
        (LoadedProfile(), null) => (
          text: 'OBDb profile: choose the model year',
          problem: false,
        ),
        (NoProfile() || null, _) => (
          text: 'Standard values only',
          problem: false,
        ),
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
