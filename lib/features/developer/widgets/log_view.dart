import '../../../core/format/formatters.dart';

import 'package:material_ui/material_ui.dart';

import '../../../core/logging/adapter_log.dart';
import '../../../ui/ui.dart';

/// The adapter log as monospace lines: `→ command ← reply`, decoded values,
/// notes and webhook sends.
class LogView extends StatelessWidget {
  const LogView({super.key, required this.entries});

  final List<LogEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mono = theme.textTheme.mono.copyWith(height: 1.6);
    final muted = scheme.onSurfaceVariant;
    final command = scheme.primary;
    final warning = context.tone(StatusTone.warning).accent;

    if (entries.isEmpty) {
      return CodeBlock(
        child: Text(
          'Nothing yet. Connect to the adapter to see its traffic here.',
          style: mono.copyWith(color: muted),
        ),
      );
    }

    TextSpan line(LogEntry entry) {
      final time = TextSpan(
        text: '${Formatters.clockWithSeconds(entry.time)}  ',
        style: TextStyle(color: muted),
      );
      final leadColor = switch (entry.kind) {
        LogEntryKind.exchange => command,
        LogEntryKind.value => muted,
        LogEntryKind.note => entry.warning ? warning : muted,
        LogEntryKind.delivery => entry.warning ? warning : command,
      };
      final body = [
        TextSpan(
          text: entry.lead,
          style: TextStyle(color: leadColor),
        ),
        if (entry.trail case final trail?)
          TextSpan(
            text: '  $trail',
            style: entry.warning ? TextStyle(color: warning) : null,
          ),
      ];
      return TextSpan(
        children: [
          time,
          ...body,
          const TextSpan(text: '\n'),
        ],
      );
    }

    return CodeBlock(
      child: SelectableText.rich(
        TextSpan(children: [for (final entry in entries) line(entry)]),
        style: mono,
      ),
    );
  }
}
