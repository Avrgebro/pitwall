import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/readings/readings.dart';
import '../../core/vehicles/vehicle.dart';
import '../../state/settings_state.dart';
import '../../ui/ui.dart';

/// Which values go in each reading, grouped by where they come from.
class ValuesToSendScreen extends ConsumerStatefulWidget {
  const ValuesToSendScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<ValuesToSendScreen> createState() => _ValuesToSendScreenState();
}

class _ValuesToSendScreenState extends ConsumerState<ValuesToSendScreen> {
  bool _showOthers = false;

  @override
  Widget build(BuildContext context) {
    final vehicle = ref.watch(vehicleProvider(widget.vehicleId));
    if (vehicle == null) {
      return const AppPage(title: 'Values to send', children: []);
    }
    final profile = ref.watch(vehicleProfileProvider(widget.vehicleId)).value;
    final options = valueOptions(profile, vehicle.modelYear);
    final selected = vehicle.selectedKeys ?? defaultKeys(options);
    final standard = options.where((o) => !o.fromProfile).toList();
    final recognised = options
        .where((o) => o.fromProfile && o.recommended)
        .toList();
    final others = options
        .where((o) => o.fromProfile && !o.recommended)
        .toList();
    final defaults = defaultKeys(options);
    Widget row(ValueOption option) => _SignalToggle(
      vehicleId: vehicle.id,
      option: option,
      defaults: defaults,
    );

    return AppPage(
      title: 'Values to send',
      subtitle: '${vehicle.name}, ${selected.length} selected',
      actions: [
        // Material 3 search: the icon opens a full-screen search view over
        // every value, standard and profile alike.
        SearchAnchor(
          viewHintText: 'Search values',
          builder: (context, controller) => IconButton(
            icon: const Icon(Symbols.search_rounded),
            tooltip: 'Search values',
            onPressed: controller.openView,
          ),
          suggestionsBuilder: (context, controller) {
            final matches = _matching(options, controller.text);
            if (matches.isEmpty) {
              return [
                InfoNote(
                  padding: Insets.card,
                  text: TextSpan(
                    text: 'No values match "${controller.text.trim()}".',
                  ),
                ),
              ];
            }
            return [for (final option in matches) row(option)];
          },
        ),
        const SizedBox(width: Insets.s),
      ],
      children: [
        _IntroPanel(
          canReset: vehicle.selectedKeys != null,
          onReset: () => ref
              .read(appSettingsProvider.notifier)
              .saveVehicle(vehicle.copyWith(selectedKeys: null)),
        ),
        const SectionHeader('Standard', trailing: 'Works on most cars'),
        RowGroup(children: [for (final option in standard) row(option)]),
        if (recognised.isNotEmpty) ...[
          SectionHeader(
            'From vehicle profile',
            trailing: _profileLabel(vehicle),
          ),
          RowGroup(children: [for (final option in recognised) row(option)]),
        ],
        if (others.isNotEmpty) ...[
          const SectionHeader('Other profile signals'),
          RowGroup(
            children: [
              GroupTile(
                icon: Symbols.manage_search_rounded,
                title: _showOthers
                    ? 'Hide ${others.length} signals'
                    : 'Show ${others.length} signals',
                subtitle:
                    'Mostly diagnostic. Each one costs an extra request every '
                    'reading.',
                trailing: Icon(
                  _showOthers ? Icons.expand_less : Icons.expand_more,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onTap: () => setState(() => _showOthers = !_showOthers),
              ),
            ],
          ),
          if (_showOthers) ...[
            const SizedBox(height: Insets.m),
            RowGroup(children: [for (final option in others) row(option)]),
          ],
        ],
      ],
    );
  }

  /// Values whose name or payload key contains [text], ignoring case.
  static List<ValueOption> _matching(List<ValueOption> options, String text) {
    final query = text.trim().toLowerCase();
    if (query.isEmpty) return options;
    return [
      for (final option in options)
        if (option.name.toLowerCase().contains(query) ||
            option.key.contains(query))
          option,
    ];
  }

  static String _profileLabel(Vehicle vehicle) => switch (vehicle.modelYear) {
    final year? => '$year profile',
    null => 'Profile',
  };
}

class _IntroPanel extends StatelessWidget {
  const _IntroPanel({required this.canReset, required this.onReset});

  final bool canReset;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(
      Insets.l,
      Insets.xs,
      Insets.l,
      Insets.xs,
    ),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: Corners.extraLargeRadius,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const InfoNote(
          text: TextSpan(
            text:
                'Only values your car actually reports are sent. Each value '
                'adds one request to every reading.',
          ),
        ),
        if (canReset)
          TextButton.icon(
            onPressed: onReset,
            icon: const Icon(Symbols.restart_alt_rounded),
            label: const Text('Reset to recommended'),
          ),
      ],
    ),
  );
}

/// One value with its on/off switch. Reads the vehicle's selection itself,
/// so it stays current wherever it's shown, the search view included.
class _SignalToggle extends ConsumerWidget {
  const _SignalToggle({
    required this.vehicleId,
    required this.option,
    required this.defaults,
  });

  final String vehicleId;
  final ValueOption option;

  /// The selection while the vehicle still uses the recommended values.
  final Set<String> defaults;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicle = ref.watch(vehicleProvider(vehicleId));
    if (vehicle == null) return const SizedBox.shrink();
    final selected = vehicle.selectedKeys ?? defaults;
    return ToggleRow(
      title: option.unit.isEmpty
          ? option.name
          : '${option.name} (${option.unit})',
      caption: option.key,
      value: selected.contains(option.key),
      onChanged: (on) => ref
          .read(appSettingsProvider.notifier)
          .saveVehicle(
            vehicle.copyWith(
              selectedKeys: on
                  ? {...selected, option.key}
                  : ({...selected}..remove(option.key)),
            ),
          ),
    );
  }
}
