import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../state/settings_state.dart';
import '../../ui/ui.dart';
import '../common/widgets/vehicle_name_field.dart';
import 'widgets/vehicle_removed_page.dart';

/// Renames a vehicle. The name is saved when typing is done, not on every
/// key: it becomes the `device` id in readings, which shouldn't go out
/// half-typed.
class VehicleNameScreen extends ConsumerStatefulWidget {
  const VehicleNameScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<VehicleNameScreen> createState() => _VehicleNameScreenState();
}

class _VehicleNameScreenState extends ConsumerState<VehicleNameScreen> {
  /// Kept from the start, as the last save comes as the screen goes.
  late final AppSettingsNotifier _settings;

  @override
  void initState() {
    super.initState();
    _settings = ref.read(appSettingsProvider.notifier);
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = ref.watch(vehicleProvider(widget.vehicleId));
    if (vehicle == null) return const VehicleRemovedPage(title: 'Name');
    return AppPage(
      title: 'Name',
      children: [
        VehicleNameField(
          initialName: vehicle.name,
          autofocus: true,
          onDone: (name) => _settings.renameVehicle(vehicle.id, name),
        ),
        const InfoNote(
          text: TextSpan(
            text:
                'Home Assistant tells your cars apart by this id. Renaming '
                'changes it, so update automations that use the old one.',
          ),
        ),
      ],
    );
  }
}
