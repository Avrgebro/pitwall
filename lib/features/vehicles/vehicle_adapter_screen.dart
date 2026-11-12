import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/bluetooth/bluetooth_gateway.dart';
import '../../core/vehicles/vehicle.dart';
import '../../state/adapter_watch_state.dart';
import '../../state/settings_state.dart';
import '../../ui/ui.dart';
import '../common/widgets/adapter_picker.dart';
import 'widgets/vehicle_page.dart';

/// Picks which adapter belongs to this vehicle: a paired one, or a
/// Bluetooth LE one found nearby.
class VehicleAdapterScreen extends ConsumerWidget {
  const VehicleAdapterScreen({super.key, required this.vehicleId});

  final String vehicleId;

  /// Makes [device] the adapter. If trips start when the adapter wakes and
  /// this one isn't watched yet, asks Android to watch it at once, so trips
  /// don't quietly stop starting.
  static Future<void> _choose(
    BuildContext context,
    WidgetRef ref,
    String vehicleId,
    BluetoothDevice device,
  ) async {
    final settings = ref.read(appSettingsProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    await settings.setAdapter(vehicleId, device);
    final vehicle = ref.read(vehicleProvider(vehicleId));
    final watchable = await ref
        .read(watchableAdaptersProvider.future)
        .then<Set<String>?>((w) => w, onError: (_) => null);
    if (vehicle == null ||
        !vehicle
            .needs(watchable: watchable)
            .contains(VehicleNeed.adapterWatch)) {
      return;
    }
    try {
      if (await settings.startTripsWhenAdapterWakes(vehicleId)) return;
    } on PlatformException {
      // Said below, as declining is.
    }
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Trips start when the adapter wakes, but Android isn\'t watching '
          'this one yet. Confirm it in Trip start.',
        ),
      ),
    );
  }

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
            onSelected: (device) => _choose(context, ref, vehicle.id, device),
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
