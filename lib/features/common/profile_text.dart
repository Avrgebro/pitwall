import '../../core/profiles/signal_set.dart';

/// Plain-language wording for vehicle profiles.
abstract final class ProfileText {
  /// Why values can't be read yet, as a heading. Requests that would change
  /// something in the car aren't "not yet"; they're never sent, and said
  /// apart.
  static String unreadable(SkipReason reason) => switch (reason) {
    SkipReason.specialFlowControl =>
      'Need a kind of request Pitwall doesn\'t support yet',
    SkipReason.extendedAddress =>
      'Sent to modules with addresses Pitwall doesn\'t support yet',
    SkipReason.unusualRequest => 'Written in a form Pitwall doesn\'t recognise',
    SkipReason.noUsableSignals => 'In a format Pitwall can\'t decode',
    SkipReason.notReadOnly => 'Would change something in the car',
  };

  /// What [reason] means, in a sentence.
  static String unreadableDetail(SkipReason reason) => switch (reason) {
    SkipReason.specialFlowControl =>
      'These modules send long answers in a way Pitwall can\'t follow yet. '
          'A future version can read them.',
    SkipReason.extendedAddress =>
      'Some modules use longer addresses than Pitwall can send to yet.',
    SkipReason.unusualRequest =>
      'The profile describes these requests in a way Pitwall can\'t use.',
    SkipReason.noUsableSignals =>
      'The values are encoded in a way Pitwall doesn\'t know.',
    SkipReason.notReadOnly =>
      'Pitwall only reads from the car, so these are never sent.',
  };

  /// "271 values for 2023".
  static String forYear(SignalSet profile, int year) =>
      '${values(profile.summaryFor(year).readable.length)} for $year';

  /// "1 value", "271 values".
  static String values(int count) => count == 1 ? '1 value' : '$count values';

  /// "Trips 12, Engine 4", the largest first.
  static String categories(List<({String category, int count})> counts) =>
      counts.map((c) => '${c.category} ${c.count}').join(', ');
}
