import '../../core/readings/unreported.dart';

/// Why a chosen value didn't come back, in a few words.
extension UnreportedText on Unreported {
  String get label => switch (this) {
    Unreported.unsupported => 'The car doesn\'t list this value',
    Unreported.noAnswer => 'The car didn\'t answer its request',
    Unreported.notInReply => 'Not in the car\'s reply',
    Unreported.unavailable => 'The car marked it unavailable',
  };
}
