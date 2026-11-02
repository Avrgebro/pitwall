import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/routes.dart';
import '../../core/bluetooth/bluetooth_gateway.dart';
import '../../core/vehicles/vehicle.dart';
import '../../state/settings_state.dart';
import '../../ui/ui.dart';
import '../common/widgets/adapter_picker.dart';
import '../common/widgets/vehicle_name_field.dart';

/// Names a new vehicle and chooses its adapter.
class AddVehicleScreen extends ConsumerStatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  ConsumerState<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends ConsumerState<AddVehicleScreen> {
  BondedDevice? _adapter;
  String _name = '';

  bool get _canSave => _adapter != null && _name.trim().isNotEmpty;

  Future<void> _save() async {
    final adapter = _adapter!;
    final vehicle = Vehicle.create(name: _name.trim()).copyWith(
      adapterAddress: adapter.address,
      adapterName: adapter.name,
      adapterType: AdapterType.classic,
    );
    await ref.read(appSettingsProvider.notifier).saveVehicle(vehicle);
    if (!mounted) return;
    // The phone is usually in the car right now, the best moment to pick
    // its stereo.
    final chooseNow = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Symbols.bluetooth_drive_rounded),
        title: Text('Choose ${vehicle.name}\'s Bluetooth?'),
        content: const Text(
          'Trips start on their own when the phone connects to the car\'s '
          'stereo or hands-free system. You can also do this later on the '
          'vehicle\'s page.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Choose now'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    context.go(
      chooseNow == true
          ? Routes.vehicleTripStart(vehicle.id)
          : Routes.vehicle(vehicle.id),
    );
  }

  @override
  Widget build(BuildContext context) => AppPage(
    title: 'Add vehicle',
    bottom: SafeArea(
      top: false,
      child: Padding(
        padding: Insets.card,
        child: SizedBox(
          width: double.infinity,
          child: GlassButton(
            onPressed: _canSave ? _save : null,
            child: const Text('Add vehicle'),
          ),
        ),
      ),
    ),
    children: [
      const SectionHeader(
        'Name this vehicle',
        padding: EdgeInsets.fromLTRB(Insets.xs, 0, Insets.xs, Insets.s),
      ),
      VehicleNameField(
        initialName: _name,
        onChanged: (name) => setState(() => _name = name),
        note: 'You can change it later.',
      ),
      const SizedBox(height: Insets.xl),
      AdapterPicker(
        selectedAddress: _adapter?.address,
        onSelected: (device) => setState(() => _adapter = device),
      ),
    ],
  );
}
