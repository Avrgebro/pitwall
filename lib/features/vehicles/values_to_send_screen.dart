import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/format/text_query.dart';
import '../../core/readings/readings.dart';
import '../../core/vehicles/vehicle.dart';
import '../../state/settings_state.dart';
import '../../ui/ui.dart';
import 'values_view.dart';
import 'widgets/vehicle_page.dart';

/// Which values go in each reading, grouped by where they come from.
class ValuesToSendScreen extends ConsumerStatefulWidget {
  const ValuesToSendScreen({super.key, required this.vehicleId, this.category});

  final String vehicleId;

  /// Shows only the profile values OBDb files under this, such as `Trips`.
  final String? category;

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
  Widget build(BuildContext context) => VehiclePage(
    vehicleId: widget.vehicleId,
    title: widget.category ?? 'Values to send',
    builder: _page,
  );

  Widget _page(BuildContext context, Vehicle vehicle, VehicleValues values) {
    final category = widget.category;
    final title = category ?? 'Values to send';
    final query = TextQuery(_query);
    final view = ValuesView.of(
      values.options,
      category: category,
      query: query,
    );
    final profile = DisclosureGroup(
      open: _showProfile,
      forcedOpen: view.profileForcedOpen,
      icon: Symbols.manage_search_rounded,
      showLabel: 'Show ${view.profile.length} signals',
      hideLabel: 'Hide ${view.profile.length} signals',
      subtitle:
          'Sent under their OBDb names, in the profile\'s units. '
          'Values from the same request share it, so they cost '
          'one request between them.',
      onToggle: () => setState(() => _showProfile = !_showProfile),
    );
    Widget row(ValueOption option) =>
        _SignalToggle(vehicleId: vehicle.id, option: option);

    // Back closes the search before leaving the page.
    return PopScope(
      canPop: !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeSearch();
      },
      // Slivers, so a profile's hundreds of signals build only as they
      // scroll into view.
      child: AppPage.slivers(
        title: title,
        subtitle:
            '${vehicle.name}, '
            '${view.sentCount(values.sent)} of ${view.options.length} on',
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
                FilterField(
                  autoFocus: true,
                  hintText: 'Search values',
                  noMatchText: view.nothingMatches
                      ? 'No values match "${query.text}".'
                      : null,
                  onChanged: (text) => setState(() => _query = text),
                )
              else
                _IntroPanel(
                  canReset: values.customised,
                  onReset: () => ref
                      .read(appSettingsProvider.notifier)
                      .resetValues(vehicle.id),
                ),
              if (view.standard.isNotEmpty) ...[
                const SectionHeader('Standard', trailing: 'Works on most cars'),
                RowGroup(
                  children: [for (final option in view.standard) row(option)],
                ),
              ],
              if (view.profile.isNotEmpty) ...[
                SectionHeader(
                  'Profile signals',
                  trailing: _profileLabel(vehicle),
                ),
                profile,
              ],
            ],
          ),
          if (view.profile.isNotEmpty && profile.listShown)
            SliverRowGroup(
              itemCount: view.profile.length,
              itemBuilder: (context, index) => row(view.profile[index]),
            ),
        ],
      ),
    );
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
                'Only values your car actually reports are sent. The more '
                'requests the values need, the longer each reading takes.',
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

/// One value with its on/off switch. Watches only whether its own value is
/// sent, so only the row that changed rebuilds.
class _SignalToggle extends ConsumerWidget {
  const _SignalToggle({required this.vehicleId, required this.option});

  final String vehicleId;
  final ValueOption option;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sent = ref.watch(
      vehicleValuesProvider(vehicleId)
          .select((values) => values?.sent.contains(option.key) ?? false),
    );
    return ToggleRow(
      title: option.unit.isEmpty
          ? option.name
          : '${option.name} (${option.unit})',
      caption: option.key,
      value: sent,
      onChanged: (on) {
        final values = ref.read(vehicleValuesProvider(vehicleId));
        if (values == null) return;
        ref
            .read(appSettingsProvider.notifier)
            .setSentValues(vehicleId, values.withSent(option.key, on: on));
      },
    );
  }
}
