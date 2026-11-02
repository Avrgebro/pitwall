import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/bluetooth/bluetooth_gateway.dart';
import '../../../core/bluetooth/device_kind.dart';
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
/// adapter or the car's head unit. Devices that suit the [role] come first;
/// the rest fold away under "Other devices". A long list gets a filter.
class AdapterPicker extends ConsumerStatefulWidget {
  const AdapterPicker({
    super.key,
    required this.selectedAddress,
    required this.onSelected,
    this.title = 'Paired adapters',
    this.role = DeviceRole.adapter,
    this.taken = const {},
  });

  final String? selectedAddress;
  final ValueChanged<BondedDevice> onSelected;
  final String title;
  final DeviceRole role;

  /// Devices that can't be chosen because another vehicle uses them: upper
  /// case address to that vehicle's name.
  final Map<String, String> taken;

  /// More paired devices than this, and the list gets a filter field.
  static const filterAbove = 5;

  @override
  ConsumerState<AdapterPicker> createState() => _AdapterPickerState();
}

class _AdapterPickerState extends ConsumerState<AdapterPicker> {
  String _query = '';
  bool _showOthers = false;

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(pairedDevicesProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SectionHeader(
                widget.title,
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
            groupValue: widget.selectedAddress,
            onChanged: (address) => widget.onSelected(
              value.firstWhere((d) => d.address == address),
            ),
            child: _list(value),
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

  Widget _list(List<BondedDevice> devices) {
    final query = _query.trim().toLowerCase();
    final matches = [
      for (final device in devices)
        if (query.isEmpty ||
            device.name.toLowerCase().contains(query) ||
            device.address.toLowerCase().contains(query))
          device,
    ];
    final suited = [
      for (final device in matches)
        if (widget.role.suits(device.kind)) device,
    ];
    final others = [
      for (final device in matches)
        if (!widget.role.suits(device.kind)) device,
    ];
    // Kept open while filtering, when nothing suits, or when the chosen
    // device is among them, so the choice is never hidden. Otherwise the
    // user opens and closes them.
    final keptOpen =
        query.isNotEmpty ||
        suited.isEmpty ||
        others.any((d) => d.address == widget.selectedAddress);
    final othersOpen = keptOpen || _showOthers;

    Widget group(List<BondedDevice> list) => RowGroup(
      children: [
        for (final device in list)
          switch (widget.taken[device.address.toUpperCase()]) {
            final owner? => ChoiceRow<String>(
              value: device.address,
              title: device.name,
              subtitle: 'Used by $owner',
              enabled: false,
            ),
            null => ChoiceRow<String>(
              value: device.address,
              title: device.name,
              subtitle: 'Classic, ${device.address}',
            ),
          },
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (devices.length > AdapterPicker.filterAbove) ...[
          SearchBar(
            hintText: 'Filter by name or address',
            leading: const Icon(Symbols.search_rounded),
            onChanged: (text) => setState(() => _query = text),
          ),
          const SizedBox(height: Insets.m),
        ],
        if (matches.isEmpty)
          InfoNote(
            text: TextSpan(text: 'No devices match "${_query.trim()}".'),
          ),
        if (suited.isNotEmpty) group(suited),
        if (others.isNotEmpty && suited.isNotEmpty) ...[
          const SectionHeader('Other devices'),
          if (!keptOpen) ...[
            RowGroup(
              children: [
                GroupTile(
                  icon: Symbols.devices_other_rounded,
                  title: _showOthers
                      ? 'Hide ${others.length} devices'
                      : 'Show ${others.length} more',
                  trailing: Icon(
                    _showOthers ? Icons.expand_less : Icons.expand_more,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onTap: () => setState(() => _showOthers = !_showOthers),
                ),
              ],
            ),
            if (_showOthers) const SizedBox(height: Insets.m),
          ],
        ],
        if (others.isNotEmpty && othersOpen) group(others),
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
