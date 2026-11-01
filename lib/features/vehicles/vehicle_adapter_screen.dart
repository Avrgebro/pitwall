import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/vehicles/vehicle.dart';
import '../../state/settings_state.dart';
import '../../ui/ui.dart';
import '../common/widgets/adapter_picker.dart';

/// Picks which paired adapter belongs to this vehicle.
class VehicleAdapterScreen extends ConsumerWidget {
  const VehicleAdapterScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicle = ref.watch(vehicleProvider(vehicleId));
    if (vehicle == null) return const AppPage(title: 'Adapter', children: []);
    return AppPage(
      title: 'Adapter',
      children: [
        AdapterPicker(
          selectedAddress: vehicle.adapterAddress,
          onSelected: (device) => ref
              .read(appSettingsProvider.notifier)
              .saveVehicle(
                vehicle.copyWith(
                  adapterAddress: device.address,
                  adapterName: device.name,
                  adapterType: AdapterType.classic,
                ),
              ),
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
  }
}
