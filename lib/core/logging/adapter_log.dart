import 'package:flutter/foundation.dart';

enum LogEntryKind {
  /// A command sent to the adapter and its reply.
  exchange,

  /// A value decoded from a reply, like `battery_v 13.6`.
  value,

  /// A remark about what happened, like "Car answered".
  note,

  /// A POST to the webhook.
  delivery,
}

@immutable
class LogEntry {
  const LogEntry({
    required this.time,
    required this.kind,
    required this.text,
    this.reply,
    this.warning = false,
  });

  final DateTime time;
  final LogEntryKind kind;

  /// The command for exchanges; the whole line otherwise.
  final String text;

  /// The adapter's reply, for exchanges.
  final String? reply;

  /// Something worth noticing, like `NO DATA` or a failed delivery.
  final bool warning;
}

/// Recent adapter and delivery activity, for the developer tools. Kept in
/// memory only, and never holds the webhook URL or credentials.
class AdapterLog {
  AdapterLog({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const maxEntries = 500;

  final DateTime Function() _clock;
  final entries = ValueNotifier<List<LogEntry>>(const []);

  void exchange(String command, String reply) => _add(
    LogEntry(
      time: _clock(),
      kind: LogEntryKind.exchange,
      text: command,
      reply: reply,
      warning: reply.contains('NO DATA') || reply.contains('ERROR'),
    ),
  );

  void value(String key, num value) => _add(
    LogEntry(time: _clock(), kind: LogEntryKind.value, text: '$key $value'),
  );

  void note(String text, {bool warning = false}) => _add(
    LogEntry(
      time: _clock(),
      kind: LogEntryKind.note,
      text: text,
      warning: warning,
    ),
  );

  void delivery(String text, {bool warning = false}) => _add(
    LogEntry(
      time: _clock(),
      kind: LogEntryKind.delivery,
      text: text,
      warning: warning,
    ),
  );

  void clear() => entries.value = const [];

  void dispose() => entries.dispose();

  void _add(LogEntry entry) {
    final next = [...entries.value, entry];
    entries.value = next.length > maxEntries
        ? next.sublist(next.length - maxEntries)
        : next;
  }
}
