import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/routes.dart';
import '../../core/bluetooth/classic_bluetooth.dart';
import '../../core/platform/file_gateway.dart';
import '../../core/readings/readings.dart';
import '../../core/vehicles/vehicle.dart';
import '../../state/infrastructure.dart';
import '../../state/settings_state.dart';
import '../../ui/ui.dart';
import '../common/profile_text.dart';
import '../common/widgets/adapter_picker.dart';
import '../common/widgets/vehicle_name_field.dart';
import 'widgets/adapter_card.dart';
import 'widgets/profile_card.dart';

/// One vehicle's settings: name, adapter, profile and values to send.
class VehicleDetailScreen extends ConsumerWidget {
  const VehicleDetailScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicle = ref.watch(vehicleProvider(vehicleId));
    if (vehicle == null) {
      return const AppPage(
        title: 'Vehicle',
        children: [InfoNote(text: TextSpan(text: 'This vehicle was removed.'))],
      );
    }
    final profile = ref.watch(vehicleProfileProvider(vehicleId)).value;
    final notifier = ref.read(appSettingsProvider.notifier);
    final options = valueOptions(profile, vehicle.modelYear);
    final selected = vehicle.selectedKeys ?? defaultKeys(options);

    return AppPage(
      title: vehicle.name,
      children: [
        const SectionHeader('Name', padding: EdgeInsets.all(Insets.xs)),
        const SizedBox(height: Insets.s),
        VehicleNameField(
          key: ValueKey(vehicle.id),
          initialName: vehicle.name,
          onChanged: (name) {
            if (name.trim().isEmpty) return;
            notifier.saveVehicle(vehicle.copyWith(name: name.trim()));
          },
        ),
        const SectionHeader('Adapter'),
        AdapterCard(
          vehicle: vehicle,
          onChange: () => _changeAdapter(context, ref, vehicle),
        ),
        const SectionHeader('Vehicle profile', trailing: 'Optional'),
        ProfileCard(
          vehicle: vehicle,
          profile: profile,
          onImport: () => _importProfile(context, ref, vehicle),
          onRemove: () => notifier.removeProfile(vehicle.id),
          onModelYear: (year) =>
              notifier.saveVehicle(vehicle.copyWith(modelYear: year)),
        ),
        const InfoNote(
          icon: Icons.help_outline,
          text: TextSpan(
            text:
                'Download your car\'s signalsets/v3/default.json from '
                'github.com/OBDb, then import it here.',
          ),
        ),
        const SectionHeader('Data'),
        GroupCard(
          children: [
            GroupTile(
              icon: Symbols.checklist_rounded,
              title: 'Values to send',
              subtitle:
                  '${selected.length} value${selected.length == 1 ? '' : 's'}',
              onTap: () => context.push(Routes.vehicleValues(vehicle.id)),
            ),
          ],
        ),
        const SizedBox(height: Insets.xl),
        const Divider(),
        const SizedBox(height: Insets.s),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _delete(context, ref, vehicle),
            style: TextButton.styleFrom(
              foregroundColor: context.tone(StatusTone.error).accent,
            ),
            icon: const Icon(Symbols.delete_rounded),
            label: const Text('Delete vehicle'),
          ),
        ),
      ],
    );
  }

  Future<void> _changeAdapter(
    BuildContext context,
    WidgetRef ref,
    Vehicle vehicle,
  ) async {
    final device = await showModalBottomSheet<BondedDevice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: Insets.page.add(const EdgeInsets.only(bottom: Insets.xl)),
        child: AdapterPicker(
          selectedAddress: vehicle.adapterAddress,
          onSelected: (device) => Navigator.pop(context, device),
        ),
      ),
    );
    if (device == null) return;
    await ref
        .read(appSettingsProvider.notifier)
        .saveVehicle(
          vehicle.copyWith(
            adapterAddress: device.address,
            adapterName: device.name,
            adapterType: AdapterType.classic,
          ),
        );
  }

  Future<void> _importProfile(
    BuildContext context,
    WidgetRef ref,
    Vehicle vehicle,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    String message;
    try {
      final file = await ref.read(fileGatewayProvider).pickJson();
      if (file == null) return;
      final profile = await ref
          .read(appSettingsProvider.notifier)
          .importProfile(vehicle.id, file);
      final year = vehicle.modelYear;
      message = year == null
          ? 'Profile imported · choose the model year'
          : 'Profile imported · ${ProfileText.applies(profile, year)}';
    } on UnreadableFileException catch (e) {
      message = e.tooLarge
          ? 'That file is too large to be a profile.'
          : 'That file isn\'t text.';
    } on FormatException catch (e) {
      message = 'That isn\'t an OBDb profile: ${e.message}';
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Vehicle vehicle,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${vehicle.name}?'),
        content: const Text(
          'Its adapter, profile and chosen values are removed from this '
          'phone. Readings already sent stay where they are.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    context.pop();
    await ref.read(appSettingsProvider.notifier).deleteVehicle(vehicle.id);
  }
}
