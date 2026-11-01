import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../state/settings_state.dart';
import '../../ui/ui.dart';
import '../common/widgets/vehicle_name_field.dart';

class VehicleNameScreen extends ConsumerWidget {
  const VehicleNameScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicle = ref.watch(vehicleProvider(vehicleId));
    if (vehicle == null) return const AppPage(title: 'Name', children: []);
    return AppPage(
      title: 'Name',
      children: [
        VehicleNameField(
          initialName: vehicle.name,
          autofocus: true,
          onChanged: (name) {
            if (name.trim().isEmpty) return;
            ref
                .read(appSettingsProvider.notifier)
                .saveVehicle(vehicle.copyWith(name: name.trim()));
          },
        ),
        const InfoNote(
          text: TextSpan(
            text:
                'Home Assistant tells your cars apart by this id. Renaming '
                'changes it, so update automations that use the old one.',
          ),
        ),
      ],
    );
  }
}
