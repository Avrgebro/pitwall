import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/platform/file_gateway.dart';
import '../../core/vehicles/vehicle.dart';
import '../../state/infrastructure.dart';
import '../../state/settings_state.dart';
import '../../ui/ui.dart';
import '../common/profile_text.dart';
import 'widgets/profile_card.dart';

/// The vehicle's optional OBDb profile: import, model year, what applies.
class VehicleProfileScreen extends ConsumerWidget {
  const VehicleProfileScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicle = ref.watch(vehicleProvider(vehicleId));
    if (vehicle == null) {
      return const AppPage(title: 'Vehicle profile', children: []);
    }
    final profile = ref.watch(vehicleProfileProvider(vehicleId)).value;
    final notifier = ref.read(appSettingsProvider.notifier);
    return AppPage(
      title: 'Vehicle profile',
      children: [
        ProfileCard(
          vehicle: vehicle,
          profile: profile,
          onImport: () => _import(context, ref, vehicle),
          onRemove: () => notifier.removeProfile(vehicle.id),
          onModelYear: (year) =>
              notifier.saveVehicle(vehicle.copyWith(modelYear: year)),
        ),
        const InfoNote(
          icon: Icons.help_outline,
          text: TextSpan(
            text:
                'Optional. A profile adds values your car only reports '
                'through manufacturer requests. Download your car\'s '
                'signalsets/v3/default.json from github.com/OBDb, then import '
                'it here.',
          ),
        ),
      ],
    );
  }

  Future<void> _import(
    BuildContext context,
    WidgetRef ref,
    Vehicle vehicle,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    String message;
    try {
      final file = await ref.read(fileGatewayProvider).pickJson();
      if (file == null) return;
      final profile = await ref
          .read(appSettingsProvider.notifier)
          .importProfile(vehicle.id, file);
      final year = vehicle.modelYear;
      message = year == null
          ? 'Profile imported · choose the model year'
          : 'Profile imported · ${ProfileText.applies(profile, year)}';
    } on UnreadableFileException catch (e) {
      message = e.tooLarge
          ? 'That file is too large to be a profile.'
          : 'That file isn\'t text.';
    } on FormatException catch (e) {
      message = 'That isn\'t an OBDb profile: ${e.message}';
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}
