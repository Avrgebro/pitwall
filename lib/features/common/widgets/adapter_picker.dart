import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/bluetooth/bluetooth_gateway.dart';
import '../../../core/bluetooth/device_kind.dart';
import '../../../core/format/text_query.dart';
import '../../../state/bluetooth_state.dart';
import '../../../ui/ui.dart';
import '../vehicle_text.dart';

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
    this.ownerOf,
  });

  final String? selectedAddress;
  final ValueChanged<BondedDevice> onSelected;
  final String title;
  final DeviceRole role;

  /// The name of the other vehicle that uses the device at an address, if
  /// any. Those devices can't be chosen.
  final String? Function(String address)? ownerOf;

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
            tone: StatusTone.error,
            text: TextSpan(text: _describe(error)),
          ),
          _ => const LoadingIndicator(),
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
    final query = TextQuery(_query);
    final matches = [
      for (final device in devices)
        if (query.matches([device.name, device.address])) device,
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
    final disclosure = DisclosureGroup(
      open: _showOthers,
      forcedOpen:
          !query.isEmpty ||
          suited.isEmpty ||
          others.any((d) => d.address == widget.selectedAddress),
      icon: Symbols.devices_other_rounded,
      showLabel: 'Show ${others.length} more',
      hideLabel: 'Hide ${others.length} devices',
      onToggle: () => setState(() => _showOthers = !_showOthers),
    );

    Widget group(List<BondedDevice> list) => RowGroup(
      children: [
        for (final device in list)
          switch (widget.ownerOf?.call(device.address)) {
            final owner? => ChoiceRow<String>(
              value: device.address,
              title: device.name,
              subtitle: 'Used by $owner',
              enabled: false,
            ),
            null => ChoiceRow<String>(
              value: device.address,
              title: device.name,
              // How it connects matters for an adapter, not a stereo.
              subtitle: switch (widget.role) {
                DeviceRole.adapter => '${device.type.label}, ${device.address}',
                DeviceRole.headUnit => device.address,
              },
            ),
          },
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (devices.length > AdapterPicker.filterAbove) ...[
          FilterField(
            hintText: 'Filter by name or address',
            noMatchText: matches.isEmpty
                ? 'No devices match "${query.text}".'
                : null,
            onChanged: (text) => setState(() => _query = text),
          ),
          const SizedBox(height: Insets.m),
        ],
        if (suited.isNotEmpty) group(suited),
        if (others.isNotEmpty && suited.isNotEmpty) ...[
          const SectionHeader('Other devices'),
          disclosure,
        ],
        if (others.isNotEmpty && disclosure.listShown) group(others),
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
