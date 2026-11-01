import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/bluetooth/classic_bluetooth.dart';
import '../../core/vehicles/vehicle.dart';
import '../../state/settings_state.dart';
import '../../ui/ui.dart';
import '../common/widgets/adapter_picker.dart';
import '../common/widgets/vehicle_name_field.dart';

/// Chooses an adapter and names a new vehicle.
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
    if (mounted) context.pushReplacement(Routes.vehicle(vehicle.id));
  }

  @override
  Widget build(BuildContext context) => AppPage(
    title: 'Add vehicle',
    bottom: SafeArea(
      child: Padding(
        padding: Insets.card,
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _canSave ? _save : null,
            child: const Text('Add vehicle'),
          ),
        ),
      ),
    ),
    children: [
      AdapterPicker(
        selectedAddress: _adapter?.address,
        onSelected: (device) => setState(() => _adapter = device),
      ),
      const SectionHeader('Name this vehicle'),
      VehicleNameField(
        initialName: _name,
        onChanged: (name) => setState(() => _name = name),
        helper: 'Sent as device. You can change it later.',
      ),
    ],
  );
}
