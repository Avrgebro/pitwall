import 'package:material_ui/material_ui.dart';

import '../../../core/bluetooth/bluetooth_gateway.dart';
import '../../../ui/ui.dart';
import 'adapter_picker.dart';
import 'vehicle_name_field.dart';

/// A vehicle ready to save: its name, trimmed, and its adapter.
typedef NewVehicle = ({String name, BondedDevice adapter});

/// What the user has entered for a new vehicle so far.
@immutable
class VehicleDraft {
  const VehicleDraft({this.name = '', this.adapter});

  final String name;
  final BondedDevice? adapter;

  /// The vehicle to save, once it has a name and an adapter.
  NewVehicle? get complete => switch (adapter) {
    final adapter? when name.trim().isNotEmpty => (
      name: name.trim(),
      adapter: adapter,
    ),
    _ => null,
  };

  VehicleDraft withName(String name) =>
      VehicleDraft(name: name, adapter: adapter);

  VehicleDraft withAdapter(BondedDevice adapter) =>
      VehicleDraft(name: name, adapter: adapter);
}

/// A new vehicle's name, then its adapter. Used by setup and by Add
/// vehicle.
///
/// Each field reports on its own, so the owner applies it to its current
/// draft rather than one captured at the last build.
class NewVehicleForm extends StatelessWidget {
  const NewVehicleForm({
    super.key,
    required this.draft,
    required this.onNameChanged,
    required this.onAdapterChanged,
  });

  final VehicleDraft draft;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<BondedDevice> onAdapterChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionHeader(
        'Name this vehicle',
        padding: SectionHeader.firstPadding,
      ),
      VehicleNameField(
        initialName: draft.name,
        onChanged: onNameChanged,
        note: 'You can change it later.',
      ),
      const SizedBox(height: Insets.xl),
      AdapterPicker(
        selectedAddress: draft.adapter?.address,
        onSelected: onAdapterChanged,
      ),
    ],
  );
}
