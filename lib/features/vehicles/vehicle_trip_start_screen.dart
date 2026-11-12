import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/bluetooth/adapter_type.dart';
import '../../core/bluetooth/bluetooth_gateway.dart';
import '../../core/bluetooth/device_kind.dart';
import '../../core/vehicles/vehicle.dart';
import '../../state/settings_state.dart';
import '../../ui/ui.dart';
import '../common/widgets/adapter_picker.dart';
import 'widgets/vehicle_page.dart';

/// What starts the vehicle's trips: its head unit connecting, or its
/// Bluetooth LE adapter waking with the car.
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
    final adapter = vehicle.adapter;
    final canWake = adapter?.type == AdapterType.ble;

    return AppPage(
      title: 'Trip start',
      subtitle: vehicle.name,
      children: [
        RadioGroup<TripStart>(
          groupValue: vehicle.tripStart,
          onChanged: (tripStart) => switch (tripStart) {
            TripStart.adapterWakes => _watchAdapter(context, ref, vehicle),
            TripStart.carBluetooth => notifier.setTripStart(
              vehicle.id,
              TripStart.carBluetooth,
            ),
            null => null,
          },
          child: RowGroup(
            children: [
              // Recommended, so first; only a Bluetooth LE adapter can.
              ChoiceRow(
                value: TripStart.adapterWakes,
                enabled: canWake,
                title: 'When the adapter wakes',
                subtitle: canWake
                    ? 'For adapters that sleep while the car is off, like '
                          'the Vgate iCar Pro. Starts when it wakes with the '
                          'car; no stereo needed.'
                    : 'Needs a Bluetooth LE adapter that sleeps while the '
                          'car is off.',
              ),
              const ChoiceRow(
                value: TripStart.carBluetooth,
                title: 'When the phone connects to the car\'s Bluetooth',
                subtitle: 'Starts within seconds of switching the car on.',
              ),
            ],
          ),
        ),
        if (vehicle.tripStart == TripStart.adapterWakes && adapter != null) ...[
          const SectionHeader('Adapter'),
          RowGroup(
            children: [
              GroupTile(
                icon: Symbols.bluetooth_searching_rounded,
                title: adapter.name,
                subtitle: adapter.watched
                    ? 'Android watches for it'
                    : 'Android isn\'t watching for it yet',
                subtitleTone: adapter.watched ? null : StatusTone.warning,
                trailing: adapter.watched
                    ? null
                    : TextButton(
                        onPressed: () => _watchAdapter(context, ref, vehicle),
                        child: const Text('Confirm'),
                      ),
              ),
            ],
          ),
          InfoNote(
            text: TextSpan(
              text:
                  'When ${adapter.name} wakes, Pitwall connects to it and '
                  'starts sending, even with the app closed. It stops a few '
                  'minutes after the car is switched off and the adapter '
                  'goes back to sleep. Only choose this for an adapter that '
                  'does sleep: one that doesn\'t would start a trip whenever '
                  'the phone passes the parked car.',
            ),
          ),
        ],
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

  /// Asks Android, with the user's confirmation, to watch for the
  /// vehicle's adapter, and makes it start trips if they confirm.
  static Future<void> _watchAdapter(
    BuildContext context,
    WidgetRef ref,
    Vehicle vehicle,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    String? message;
    try {
      final watched = await ref
          .read(appSettingsProvider.notifier)
          .startTripsWhenAdapterWakes(vehicle.id);
      if (!watched) {
        message =
            'Android isn\'t watching for the adapter, so trips still '
            'start as before.';
      }
    } on PlatformException {
      message =
          'Android couldn\'t watch for the adapter. Try again with the '
          'adapter awake and nearby.';
    }
    if (message != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
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
