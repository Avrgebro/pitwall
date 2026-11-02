import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../state/settings_state.dart';
import '../../ui/ui.dart';
import '../common/widgets/vehicle_name_field.dart';
import 'widgets/vehicle_removed_page.dart';

/// Renames a vehicle. The name is saved when typing is done (Done, leaving
/// the field, or going back), not on every key: it becomes the `device`
/// id in readings, which shouldn't go out half-typed.
class VehicleNameScreen extends ConsumerStatefulWidget {
  const VehicleNameScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<VehicleNameScreen> createState() => _VehicleNameScreenState();
}

class _VehicleNameScreenState extends ConsumerState<VehicleNameScreen> {
  /// What's typed, once something is.
  String? _typed;

  Future<void> _save() async {
    final name = _typed?.trim();
    final vehicle = ref.read(vehicleProvider(widget.vehicleId));
    if (name == null || name.isEmpty || vehicle == null) return;
    if (name == vehicle.name) return;
    await ref
        .read(appSettingsProvider.notifier)
        .renameVehicle(vehicle.id, name);
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = ref.watch(vehicleProvider(widget.vehicleId));
    if (vehicle == null) return const VehicleRemovedPage(title: 'Name');
    return PopScope(
      onPopInvokedWithResult: (_, _) => _save(),
      child: AppPage(
        title: 'Name',
        children: [
          VehicleNameField(
            initialName: vehicle.name,
            autofocus: true,
            onChanged: (name) => _typed = name,
            onDone: (_) => _save(),
          ),
          const InfoNote(
            text: TextSpan(
              text:
                  'Home Assistant tells your cars apart by this id. Renaming '
                  'changes it, so update automations that use the old one.',
            ),
          ),
        ],
      ),
    );
  }
}
