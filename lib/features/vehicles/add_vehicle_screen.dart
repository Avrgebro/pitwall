import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/routes.dart';
import '../../state/settings_state.dart';
import '../../ui/ui.dart';
import '../common/widgets/new_vehicle_form.dart';

/// Names a new vehicle and chooses its adapter.
class AddVehicleScreen extends ConsumerStatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  ConsumerState<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends ConsumerState<AddVehicleScreen> {
  VehicleDraft _draft = const VehicleDraft();

  Future<void> _save() async {
    final vehicle = await ref
        .read(appSettingsProvider.notifier)
        .addVehicle(name: _draft.name, adapter: _draft.adapter!);
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
            onPressed: _draft.isComplete ? _save : null,
            child: const Text('Add vehicle'),
          ),
        ),
      ),
    ),
    children: [
      NewVehicleForm(
        draft: _draft,
        onNameChanged: (name) => setState(() => _draft = _draft.withName(name)),
        onAdapterChanged: (device) =>
            setState(() => _draft = _draft.withAdapter(device)),
      ),
    ],
  );
}
