import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/bluetooth/classic_bluetooth.dart';
import '../../../core/platform/permission_gateway.dart';
import '../../../state/infrastructure.dart';
import '../../../ui/ui.dart';

/// Paired Bluetooth devices, after asking for the permission to list them.
final pairedDevicesProvider = FutureProvider.autoDispose<List<BondedDevice>>((
  ref,
) async {
  final granted = await ref
      .read(permissionGatewayProvider)
      .request(AppPermission.bluetooth);
  if (!granted) throw const BluetoothPermissionDenied();
  return ref.read(bluetoothGatewayProvider).bondedDevices();
});

class BluetoothPermissionDenied implements Exception {
  const BluetoothPermissionDenied();
}

/// The paired devices as a single-choice list, used to pick an OBD
/// adapter or the car's head unit.
class AdapterPicker extends ConsumerWidget {
  const AdapterPicker({
    super.key,
    required this.selectedAddress,
    required this.onSelected,
    this.title = 'Paired adapters',
  });

  final String? selectedAddress;
  final ValueChanged<BondedDevice> onSelected;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(pairedDevicesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SectionHeader(
                title,
                padding: const EdgeInsets.all(Insets.xs),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () => ref.invalidate(pairedDevicesProvider),
            ),
          ],
        ),
        switch (devices) {
          AsyncData(:final value) when value.isEmpty => const InfoNote(
            text: TextSpan(
              text:
                  'No paired devices yet. Pair the adapter in Android\'s '
                  'Bluetooth settings, then refresh.',
            ),
          ),
          AsyncData(:final value) => RadioGroup<String>(
            groupValue: selectedAddress,
            onChanged: (address) =>
                onSelected(value.firstWhere((d) => d.address == address)),
            child: RowGroup(
              children: [
                for (final device in value)
                  ChoiceRow<String>(
                    value: device.address,
                    title: device.name,
                    subtitle: 'Classic · ${device.address}',
                  ),
              ],
            ),
          ),
          AsyncError(:final error) => InfoNote(
            icon: Icons.error_outline,
            text: TextSpan(text: _describe(error)),
          ),
          _ => const Padding(
            padding: EdgeInsets.all(Insets.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
        },
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => _showPairingHelp(context),
            child: const Text('My adapter isn\'t listed'),
          ),
        ),
      ],
    );
  }

  static String _describe(Object error) => switch (error) {
    BluetoothPermissionDenied() =>
      'Pitwall needs the Bluetooth permission to see paired devices.',
    PlatformException(code: 'disabled') => 'Bluetooth is off. Turn it on.',
    _ => 'Couldn\'t list Bluetooth devices.',
  };

  static Future<void> _showPairingHelp(BuildContext context) => showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Pair the adapter first'),
      content: const Text(
        'Plug the adapter in and switch the ignition on. Then open Android '
        'Settings → Connected devices → Pair new device, and choose it. The '
        'PIN is usually 1234 or 0000. Come back and refresh.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
