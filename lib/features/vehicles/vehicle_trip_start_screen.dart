import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/bluetooth/bluetooth_gateway.dart';
import '../../core/bluetooth/device_kind.dart';
import '../../core/vehicles/vehicle.dart';
import '../../state/settings_state.dart';
import '../../ui/ui.dart';
import '../common/widgets/adapter_picker.dart';
import 'widgets/vehicle_page.dart';

/// What starts the vehicle's trips: its head unit connecting, for now.
class VehicleTripStartScreen extends ConsumerWidget {
  const VehicleTripStartScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => VehiclePage(
    vehicleId: vehicleId,
    title: 'Trip start',
    builder: (context, values) => _page(context, ref, values.vehicle),
  );

  Widget _page(BuildContext context, WidgetRef ref, Vehicle vehicle) {
    final notifier = ref.read(appSettingsProvider.notifier);
    final headUnit = vehicle.headUnit?.name;

    return AppPage(
      title: 'Trip start',
      subtitle: vehicle.name,
      children: [
        RadioGroup<TripStart>(
          groupValue: vehicle.tripStart,
          onChanged: (tripStart) {
            if (tripStart != null) notifier.setTripStart(vehicle.id, tripStart);
          },
          child: const RowGroup(
            children: [
              ChoiceRow(
                value: TripStart.carBluetooth,
                title: 'When the phone connects to the car\'s Bluetooth',
                subtitle: 'Starts within seconds of switching the car on.',
              ),
              ChoiceRow(
                value: TripStart.drivingDetection,
                enabled: false,
                title: 'When driving is detected',
                subtitle:
                    'For cars without Bluetooth audio. Not available yet.',
              ),
            ],
          ),
        ),
        if (vehicle.tripStart == TripStart.carBluetooth) ...[
          const SectionHeader('Car head unit'),
          RowGroup(
            children: [
              GroupTile(
                icon: Symbols.bluetooth_rounded,
                title: headUnit ?? 'Not chosen yet',
                subtitle: headUnit == null
                    ? 'Choose the car\'s stereo or hands-free system'
                    : vehicle.headUnit?.address,
                trailing: TextButton(
                  onPressed: () => chooseHeadUnit(context, ref, vehicle),
                  child: Text(headUnit == null ? 'Choose' : 'Change'),
                ),
              ),
            ],
          ),
          InfoNote(
            text: TextSpan(
              text:
                  'When the phone connects to it, Pitwall connects to '
                  '${vehicle.name}\'s adapter and starts sending. It stops a '
                  'few minutes after the car is switched off or the phone '
                  'leaves the car. Disconnecting from the stereo, say to '
                  'hand it to someone else, doesn\'t stop it.',
            ),
          ),
        ],
      ],
    );
  }

  /// Opens the paired devices, car audio first, and saves the one chosen.
  /// Head units other vehicles use can't be chosen.
  static Future<void> chooseHeadUnit(
    BuildContext context,
    WidgetRef ref,
    Vehicle vehicle,
  ) async {
    final device = await showAppSheet<BluetoothDevice>(
      context,
      builder: (context) => AdapterPicker(
        title: 'Paired devices',
        role: DeviceRole.headUnit,
        selectedAddress: vehicle.headUnit?.address,
        // Asked as the list shows, not from when the sheet opened.
        ownerOf: (address) => ref
            .read(appSettingsProvider)
            .value
            ?.otherHeadUnitOwner(address, vehicleId: vehicle.id)
            ?.name,
        onSelected: (device) => Navigator.pop(context, device),
      ),
    );
    if (device == null) return;
    await ref
        .read(appSettingsProvider.notifier)
        .setHeadUnit(vehicle.id, address: device.address, name: device.name);
  }
}
