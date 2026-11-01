import '../../core/profiles/signal_set.dart';

/// Plain-language wording for vehicle profiles.
abstract final class ProfileText {
  static String skipReason(SkipReason reason) => switch (reason) {
    SkipReason.notReadOnly => 'Would change something in the car, never sent',
    SkipReason.unusualRequest => 'Requests Pitwall doesn\'t understand',
    SkipReason.extendedAddress => 'Need addressing the adapter can\'t do yet',
    SkipReason.specialFlowControl =>
      'Need flow control the adapter can\'t do yet',
    SkipReason.noUsableSignals => 'Nothing Pitwall can read in them',
  };

  /// Skipped requests grouped by reason, most common first.
  static List<({int count, String reason})> skippedSummary(
    List<SkippedCommand> skipped,
  ) {
    final counts = <SkipReason, int>{};
    for (final command in skipped) {
      counts[command.reason] = (counts[command.reason] ?? 0) + 1;
    }
    return [
      for (final MapEntry(:key, :value)
          in counts.entries.toList()..sort((a, b) => b.value - a.value))
        (count: value, reason: skipReason(key)),
    ];
  }

  /// "55 requests apply to 2023".
  static String applies(SignalSet profile, int year) {
    final count = profile.commandsFor(year).length;
    return count == 1
        ? '1 request applies to $year'
        : '$count requests apply to $year';
  }
}
