import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../state/settings_state.dart';
import '../../ui/ui.dart';
import '../common/widgets/adapter_picker.dart';
import 'widgets/vehicle_page.dart';

/// Picks which adapter belongs to this vehicle: a paired one, or a
/// Bluetooth LE one found nearby.
class VehicleAdapterScreen extends ConsumerWidget {
  const VehicleAdapterScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => VehiclePage(
    vehicleId: vehicleId,
    title: 'Adapter',
    builder: (context, values) {
      final vehicle = values.vehicle;
      return AppPage(
        title: 'Adapter',
        children: [
          AdapterPicker(
            selectedAddress: vehicle.adapter?.address,
            onSelected: (device) => ref
                .read(appSettingsProvider.notifier)
                .setAdapter(vehicle.id, device),
          ),
          const InfoNote(
            text: TextSpan(
              text:
                  'Each vehicle has its own adapter. Pitwall knows which car '
                  'it\'s in by which adapter answers.',
            ),
          ),
        ],
      );
    },
  );
}
