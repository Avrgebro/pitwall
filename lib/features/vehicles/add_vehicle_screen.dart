import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

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

  Future<void> _save(NewVehicle draft) async {
    final settings = ref.read(appSettingsProvider.notifier);
    final vehicle = await settings.addVehicle(
      name: draft.name,
      adapter: draft.adapter,
    );
    // A Bluetooth LE adapter's waking can start trips: one confirmation
    // in Android's dialog, while it's awake and nearby, and that's done.
    if (await _adapterWakes(settings, vehicle.id)) {
      if (mounted) context.go(Routes.vehicle(vehicle.id));
      return;
    }
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

  /// Whether trips now start when the adapter wakes. Android failing to
  /// is no different here from the user declining: the car's Bluetooth is
  /// offered next, and Trip start says what's missing.
  static Future<bool> _adapterWakes(
    AppSettingsNotifier settings,
    String vehicleId,
  ) async {
    try {
      return await settings.offerAdapterWake(vehicleId);
    } on PlatformException {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
    title: 'Add vehicle',
    bottom: PinnedActions(
      child: SizedBox(
        width: double.infinity,
        child: GlassButton(
          onPressed: switch (_draft.complete) {
            final draft? => () => _save(draft),
            null => null,
          },
          child: const Text('Add vehicle'),
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
