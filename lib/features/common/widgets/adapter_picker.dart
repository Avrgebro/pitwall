import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/bluetooth/adapter_type.dart';
import '../../../core/bluetooth/bluetooth_gateway.dart';
import '../../../core/bluetooth/device_kind.dart';
import '../../../core/format/formatters.dart';
import '../../../core/format/text_query.dart';
import '../../../state/bluetooth_state.dart';
import '../../../ui/ui.dart';

/// Bluetooth devices as a single-choice list, used to pick an OBD adapter
/// or the car's head unit. For an adapter, Bluetooth LE devices found
/// nearby join the paired ones, as those need no pairing; a head unit is
/// always paired. Devices that suit the [role] come first; the rest fold
/// away under "Other devices". A long list gets a filter.
class AdapterPicker extends ConsumerStatefulWidget {
  const AdapterPicker({
    super.key,
    required this.selectedAddress,
    required this.onSelected,
    this.title = 'Adapters',
    this.role = DeviceRole.adapter,
    this.ownerOf,
  });

  final String? selectedAddress;
  final ValueChanged<BluetoothDevice> onSelected;
  final String title;
  final DeviceRole role;

  /// The name of the other vehicle that uses the device at an address, if
  /// any. Those devices can't be chosen.
  final String? Function(String address)? ownerOf;

  /// More devices than this, and the list gets a filter field.
  static const filterAbove = 5;

  @override
  ConsumerState<AdapterPicker> createState() => _AdapterPickerState();
}

class _AdapterPickerState extends ConsumerState<AdapterPicker> {
  TextQuery _query = TextQuery.none;
  bool _showOthers = false;

  @override
  Widget build(BuildContext context) {
    // Looking for Bluetooth LE adapters only while choosing one.
    final looks = widget.role == DeviceRole.adapter;
    final nearby = looks ? ref.watch(nearbyDevicesProvider) : null;
    final devices = switch (ref.watch(pairedDevicesProvider)) {
      AsyncData(value: final paired) => AsyncData([
        ...paired,
        for (final device in nearby?.value ?? const <BluetoothDevice>[])
          if (!paired.any((p) => p.address == device.address)) device,
      ]),
      final other => other,
    };
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
              onPressed: () {
                ref.invalidate(pairedDevicesProvider);
                if (looks) ref.invalidate(nearbyDevicesProvider);
              },
            ),
          ],
        ),
        if (nearby case AsyncData()) ...[
          const _Looking(),
          const SizedBox(height: Insets.s),
        ],
        switch (devices) {
          AsyncData(:final value) when value.isEmpty => InfoNote(
            text: TextSpan(
              text: looks
                  ? 'No adapters yet. A Bluetooth LE adapter shows up here '
                        'once it\'s plugged in with the ignition on. A '
                        'classic one needs pairing in Android\'s Bluetooth '
                        'settings first.'
                  : 'No paired devices yet. Pair it in Android\'s '
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

  Widget _list(List<BluetoothDevice> devices) {
    final matches = [
      for (final device in devices)
        if (_query.matches([device.name, device.address])) device,
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
    final othersList = Disclosure(
      forced:
          !_query.isEmpty ||
          suited.isEmpty ||
          others.any((d) => d.address == widget.selectedAddress),
      open: _showOthers,
    );

    Widget group(List<BluetoothDevice> list) => RowGroup(
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
              subtitle: device.address,
              // How it connects matters for an adapter, not a stereo.
              badge: switch (widget.role) {
                DeviceRole.adapter => _TypeBadge(device.type),
                DeviceRole.headUnit => null,
              },
            ),
          },
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Kept while a filter is set, so what filters the list stays in
        // view and can be cleared.
        if (devices.length > AdapterPicker.filterAbove || !_query.isEmpty) ...[
          FilterField(
            hintText: 'Filter by name or address',
            noun: 'devices',
            query: _query,
            matches: matches.length,
            onChanged: (query) => setState(() => _query = query),
          ),
          const SizedBox(height: Insets.m),
        ],
        if (suited.isNotEmpty) group(suited),
        if (others.isNotEmpty && suited.isNotEmpty) ...[
          const SectionHeader('Other devices'),
          DisclosureGroup(
            disclosure: othersList,
            icon: Symbols.devices_other_rounded,
            contents: Formatters.count(others.length, 'device'),
            onToggle: () => setState(() => _showOthers = !_showOthers),
          ),
        ],
        if (others.isNotEmpty && othersList.showsList) group(others),
      ],
    );
  }

  static String _describe(Object error) => switch (error) {
    BluetoothPermissionDenied() =>
      'Pitwall needs the Nearby devices permission to find adapters.',
    PlatformException(code: 'disabled') => 'Bluetooth is off. Turn it on.',
    _ => 'Couldn\'t list Bluetooth devices.',
  };

  static Future<void> _showPairingHelp(BuildContext context) => showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Finding your adapter'),
      content: const Text(
        'Plug the adapter in and switch the ignition on.\n\n'
        'A Bluetooth LE adapter needs no pairing: it shows up here on its '
        'own within a few seconds. If it doesn\'t, unplug it and plug it '
        'back in.\n\n'
        'A classic adapter needs pairing first: open Android Settings → '
        'Connected devices → Pair new device, and choose it. The PIN is '
        'usually 1234 or 0000. Come back and refresh.',
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

/// Says the picker is still looking for Bluetooth LE adapters nearby.
class _Looking extends StatelessWidget {
  const _Looking();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          Symbols.bluetooth_searching_rounded,
          size: Sizes.iconSmall,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: Insets.s),
        Expanded(
          child: Text(
            'Looking for Bluetooth LE adapters nearby',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// How an adapter connects, as a small badge by its name.
class _TypeBadge extends StatelessWidget {
  const _TypeBadge(this.type);

  final AdapterType type;

  @override
  Widget build(BuildContext context) => Tag(
    switch (type) {
      AdapterType.ble => 'BLE',
      AdapterType.classic => 'Classic',
    },
    tone: switch (type) {
      AdapterType.ble => StatusTone.active,
      AdapterType.classic => StatusTone.neutral,
    },
  );
}
