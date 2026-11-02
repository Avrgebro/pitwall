import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/logging/adapter_log.dart';
import '../../core/vehicles/vehicle.dart';
import '../../state/infrastructure.dart';
import '../../state/session_state.dart';
import '../../state/settings_state.dart';
import '../../state/trip_state.dart';
import '../../ui/ui.dart';
import 'widgets/log_view.dart';
import 'widgets/session_panel.dart';

/// Raw adapter traffic, a manual session and a raw command input.
class DeveloperScreen extends ConsumerStatefulWidget {
  const DeveloperScreen({super.key});

  @override
  ConsumerState<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends ConsumerState<DeveloperScreen> {
  final _command = TextEditingController();

  /// The vehicle picked here, when no session or trip decides.
  String? _chosenId;

  @override
  void dispose() {
    _command.dispose();
    super.dispose();
  }

  void _send() {
    final commands = _command.text
        .split(RegExp(r'[,\s]+'))
        .where((c) => c.isNotEmpty)
        .map((c) => c.toUpperCase())
        .toList();
    if (commands.isEmpty) return;
    ref.read(sessionProvider.notifier).sendRaw(commands);
    _command.clear();
  }

  Future<void> _chooseVehicle(List<Vehicle> vehicles, Vehicle? current) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SingleChildScrollView(
        padding: Insets.page.copyWith(bottom: Insets.xl),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(
                'Connect to',
                padding: EdgeInsets.fromLTRB(Insets.xs, 0, Insets.xs, Insets.s),
              ),
              RadioGroup<String>(
                groupValue: current?.id,
                onChanged: (id) => Navigator.pop(context, id),
                child: RowGroup(
                  children: [
                    for (final vehicle in vehicles)
                      ChoiceRow<String>(
                        value: vehicle.id,
                        title: vehicle.name,
                        subtitle: vehicle.adapterName,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (id != null) setState(() => _chosenId = id);
  }

  @override
  Widget build(BuildContext context) {
    final log = ref.watch(adapterLogProvider);
    final session = ref.watch(sessionProvider);
    final trip = ref.watch(tripProvider);
    final settings = ref.watch(appSettingsProvider).value;
    final withAdapter = [
      for (final vehicle in settings?.vehicles ?? const <Vehicle>[])
        if (vehicle.adapterAddress != null) vehicle,
    ];
    Vehicle? find(String? id) =>
        withAdapter.where((v) => v.id == id).firstOrNull;
    // A session or trip in progress decides the vehicle; otherwise the one
    // picked here, or the one seen most recently.
    final liveId = session.vehicleId ?? trip.vehicleId;
    final vehicle =
        find(liveId) ??
        find(_chosenId) ??
        find(settings?.mostRecentVehicle?.id) ??
        withAdapter.firstOrNull;
    final canChoose =
        liveId == null && !trip.isActive && withAdapter.length > 1;

    return ValueListenableBuilder<List<LogEntry>>(
      valueListenable: log.entries,
      builder: (context, entries, _) => AppPage(
        title: 'Developer tools',
        bottom: _CommandBar(
          controller: _command,
          enabled: session.isConnected && !session.busy,
          onSend: _send,
        ),
        children: [
          const SectionHeader(
            'Session',
            padding: EdgeInsets.fromLTRB(Insets.xs, 0, Insets.xs, Insets.s),
          ),
          SessionPanel(
            vehicle: vehicle,
            onChooseVehicle: canChoose
                ? () => _chooseVehicle(withAdapter, vehicle)
                : null,
          ),
          Padding(
            padding: const EdgeInsets.only(top: Insets.l, bottom: Insets.s),
            child: Row(
              children: [
                const Expanded(
                  child: SectionHeader(
                    'Adapter log',
                    padding: EdgeInsets.all(Insets.xs),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: entries.isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(
                            ClipboardData(text: logAsText(entries)),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Log copied to clipboard'),
                              action: SnackBarAction(
                                label: 'OK',
                                onPressed: () {},
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Symbols.content_copy_rounded),
                  label: const Text('Copy'),
                ),
                const SizedBox(width: Insets.s),
                OutlinedButton.icon(
                  onPressed: entries.isEmpty ? null : log.clear,
                  icon: const Icon(Symbols.delete_sweep_rounded),
                  label: const Text('Clear'),
                ),
              ],
            ),
          ),
          LogView(entries: entries),
        ],
      ),
    );
  }
}

class _CommandBar extends StatelessWidget {
  const _CommandBar({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassBar(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.l,
          Insets.l,
          Insets.l,
          Insets.s,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: enabled,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.characters,
                    style: theme.textTheme.mono.copyWith(
                      fontSize: theme.textTheme.bodyLarge?.fontSize,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Raw command',
                      hintText: 'e.g. 010C',
                    ),
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                const SizedBox(width: Insets.s),
                IconButton.filled(
                  onPressed: enabled ? onSend : null,
                  icon: const Icon(Symbols.send_rounded),
                  tooltip: 'Send',
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.l,
                Insets.xs,
                Insets.l,
                0,
              ),
              child: Text(
                'Sent straight to the adapter. Only while connected.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
