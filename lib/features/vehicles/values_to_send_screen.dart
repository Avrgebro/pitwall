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
  String _search = '';

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
    final query = _search.trim().toLowerCase();
    final matches = query.isEmpty
        ? others
        : others
              .where(
                (o) =>
                    o.name.toLowerCase().contains(query) ||
                    o.key.contains(query),
              )
              .toList();

    void toggle(String key, bool on) => ref
        .read(appSettingsProvider.notifier)
        .saveVehicle(
          vehicle.copyWith(
            selectedKeys: on
                ? {...selected, key}
                : ({...selected}..remove(key)),
          ),
        );

    Widget row(ValueOption option) => ToggleRow(
      title: option.unit.isEmpty
          ? option.name
          : '${option.name} (${option.unit})',
      caption: option.key,
      value: selected.contains(option.key),
      onChanged: (on) => toggle(option.key, on),
    );

    return AppPage(
      title: 'Values to send',
      subtitle: '${vehicle.name} · ${selected.length} selected',
      children: [
        _IntroPanel(
          canReset: vehicle.selectedKeys != null,
          onReset: () => ref
              .read(appSettingsProvider.notifier)
              .saveVehicle(vehicle.copyWith(selectedKeys: null)),
        ),
        const SectionHeader('Standard', trailing: 'Works on most cars'),
        GroupCard(children: [for (final option in standard) row(option)]),
        if (recognised.isNotEmpty) ...[
          SectionHeader(
            'From vehicle profile',
            trailing: _profileLabel(vehicle),
          ),
          GroupCard(children: [for (final option in recognised) row(option)]),
        ],
        if (others.isNotEmpty) ...[
          const SizedBox(height: Insets.l),
          GroupCard(
            children: [
              ExpansionTile(
                title: Text('Other profile signals (${others.length})'),
                subtitle: const Text(
                  'Mostly diagnostic. Each one costs an extra request every '
                  'reading.',
                ),
                childrenPadding: const EdgeInsets.only(bottom: Insets.s),
                children: [
                  Padding(
                    padding: Insets.page,
                    child: SearchBar(
                      hintText: 'Search signals',
                      leading: const Icon(Symbols.search_rounded),
                      elevation: const WidgetStatePropertyAll(0),
                      onChanged: (text) => setState(() => _search = text),
                    ),
                  ),
                  if (query.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Insets.xl,
                        Insets.s,
                        Insets.xl,
                        0,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${matches.length} of ${others.length} match',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  for (final option in matches) row(option),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }

  static String _profileLabel(Vehicle vehicle) => switch (vehicle.modelYear) {
    final year? => 'Profile · $year',
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
