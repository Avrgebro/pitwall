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
  bool _showProfile = false;

  /// Whether the search bar is open, and what's typed in it.
  bool _searching = false;
  String _query = '';

  void _closeSearch() => setState(() {
    _searching = false;
    _query = '';
  });

  @override
  Widget build(BuildContext context) {
    final vehicle = ref.watch(vehicleProvider(widget.vehicleId));
    if (vehicle == null) {
      return const AppPage(title: 'Values to send', children: []);
    }
    final profile = ref.watch(vehicleProfileProvider(widget.vehicleId)).value;
    final options = valueOptions(profile, vehicle.modelYear);
    final selected = vehicle.selectedKeys ?? defaultKeys(options);
    // While searching, every section keeps only the values that match.
    final query = _query.trim().toLowerCase();
    final filtering = _searching && query.isNotEmpty;
    final shown = filtering ? _matching(options, query) : options;
    final standard = shown.where((o) => !o.fromProfile).toList();
    final fromProfile = shown.where((o) => o.fromProfile).toList();
    final defaults = defaultKeys(options);
    Widget row(ValueOption option) => _SignalToggle(
      vehicleId: vehicle.id,
      option: option,
      defaults: defaults,
    );

    // Back closes the search before leaving the page.
    return PopScope(
      canPop: !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeSearch();
      },
      // Slivers, so a profile's hundreds of signals build only as they
      // scroll into view.
      child: AppPage.slivers(
        title: 'Values to send',
        subtitle: '${vehicle.name}, ${selected.length} selected',
        actions: [
          IconButton(
            icon: Icon(
              _searching ? Symbols.close_rounded : Symbols.search_rounded,
            ),
            tooltip: _searching ? 'Close search' : 'Search values',
            onPressed: _searching
                ? _closeSearch
                : () => setState(() => _searching = true),
          ),
          const SizedBox(width: Insets.s),
        ],
        slivers: [
          SliverList.list(
            children: [
              if (_searching)
                SearchBar(
                  autoFocus: true,
                  hintText: 'Search values',
                  leading: const Icon(Symbols.search_rounded),
                  onChanged: (text) => setState(() => _query = text),
                )
              else
                _IntroPanel(
                  canReset: vehicle.selectedKeys != null,
                  onReset: () => ref
                      .read(appSettingsProvider.notifier)
                      .saveVehicle(vehicle.copyWith(selectedKeys: null)),
                ),
              if (shown.isEmpty) ...[
                const SizedBox(height: Insets.m),
                InfoNote(
                  text: TextSpan(text: 'No values match "${_query.trim()}".'),
                ),
              ],
              if (standard.isNotEmpty) ...[
                const SectionHeader('Standard', trailing: 'Works on most cars'),
                RowGroup(
                  children: [for (final option in standard) row(option)],
                ),
              ],
              if (fromProfile.isNotEmpty) ...[
                SectionHeader(
                  'Profile signals',
                  trailing: _profileLabel(vehicle),
                ),
              ],
              // Matches are what was searched for; no need to expand them.
              if (fromProfile.isNotEmpty && !filtering) ...[
                RowGroup(
                  children: [
                    GroupTile(
                      icon: Symbols.manage_search_rounded,
                      title: _showProfile
                          ? 'Hide ${fromProfile.length} signals'
                          : 'Show ${fromProfile.length} signals',
                      subtitle:
                          'Sent under their OBDb names, in the profile\'s units. '
                          'Each one adds a request to every reading.',
                      trailing: Icon(
                        _showProfile ? Icons.expand_less : Icons.expand_more,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onTap: () => setState(() => _showProfile = !_showProfile),
                    ),
                  ],
                ),
                if (_showProfile) const SizedBox(height: Insets.m),
              ],
            ],
          ),
          if (fromProfile.isNotEmpty && (filtering || _showProfile))
            SliverRowGroup(
              itemCount: fromProfile.length,
              itemBuilder: (context, index) => row(fromProfile[index]),
            ),
        ],
      ),
    );
  }

  /// Values whose name or payload key contains [query], which is
  /// lowercase.
  static List<ValueOption> _matching(List<ValueOption> options, String query) =>
      [
        for (final option in options)
          if (option.name.toLowerCase().contains(query) ||
              option.key.contains(query))
            option,
      ];

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
/// so only the row that changed rebuilds.
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
