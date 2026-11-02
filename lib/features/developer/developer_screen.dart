import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/logging/adapter_log.dart';
import '../../state/focus_state.dart';
import '../../state/infrastructure.dart';
import '../../state/session_state.dart';
import '../../state/settings_state.dart';
import '../../ui/ui.dart';
import '../common/widgets/vehicle_picker_sheet.dart';
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

  @override
  Widget build(BuildContext context) {
    final log = ref.watch(adapterLogProvider);
    final session = ref.watch(sessionProvider);
    final vehicleCount = ref.watch(
      appSettingsProvider.select((s) => s.value?.vehicles.length ?? 0),
    );

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
            vehicle: ref.watch(focusedVehicleProvider),
            onChooseVehicle: vehicleCount > 1
                ? () => VehiclePickerSheet.show(context, title: 'Connect to')
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
