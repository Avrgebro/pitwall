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
    final mono = theme.textTheme.mono.copyWith(
      color: scheme.onSurface,
      height: 1.6,
    );
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
      final body = switch (entry.kind) {
        LogEntryKind.exchange => [
          TextSpan(
            text: '→ ${entry.text}',
            style: TextStyle(color: command),
          ),
          TextSpan(
            text: '  ← ${_compact(entry.reply ?? '')}',
            style: entry.warning ? TextStyle(color: warning) : null,
          ),
        ],
        LogEntryKind.value => [
          TextSpan(
            text: '= ${entry.text}',
            style: TextStyle(color: muted),
          ),
        ],
        LogEntryKind.note => [
          TextSpan(
            text: '- ${entry.text}',
            style: TextStyle(color: entry.warning ? warning : muted),
          ),
        ],
        LogEntryKind.delivery => [
          TextSpan(
            text: entry.text,
            style: TextStyle(color: entry.warning ? warning : command),
          ),
        ],
      };
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

  /// Raw replies have line breaks between ECUs; one line reads better.
  static String _compact(String reply) =>
      reply.replaceAll(RegExp(r'[\r\n]+'), ' ').replaceAll('>', '').trim();
}

/// Plain text of the log, for copying.
String logAsText(List<LogEntry> entries) => entries
    .map((entry) {
      final time = Formatters.clockWithSeconds(entry.time);
      return switch (entry.kind) {
        LogEntryKind.exchange =>
          '$time → ${entry.text} ← ${LogView._compact(entry.reply ?? '')}',
        LogEntryKind.value => '$time = ${entry.text}',
        LogEntryKind.note => '$time - ${entry.text}',
        LogEntryKind.delivery => '$time ${entry.text}',
      };
    })
    .join('\n');
