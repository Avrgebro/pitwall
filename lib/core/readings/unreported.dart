import '../obd/can_id.dart';

/// Why a value that was asked for isn't in a reading, with [label] saying
/// so in a few words, for the adapter log and the values page alike.
enum Unreported {
  /// A standard value the car doesn't list among the ones it supports, so
  /// it isn't asked for.
  unsupported('The car doesn\'t list this value'),

  /// Nothing answered the request, or the car refused it.
  noAnswer('The car didn\'t answer its request'),

  /// The car answered, but its reply is too short to hold the value.
  notInReply('Not in the car\'s reply'),

  /// The car marked it as unavailable, or it was outside its valid range.
  unavailable('The car marked it unavailable'),

  /// A value the adapter measures itself, such as the battery voltage,
  /// that it didn't.
  notMeasured('The adapter didn\'t measure it'),

  /// It's only in requests that need flow control, which this adapter
  /// can't set.
  adapterCannot('This adapter can\'t read it');

  const Unreported(this.label);

  final String label;
}

/// What a read found: the values; why each other one asked for isn't
/// among them, where its reply says why; and, for those whose request got
/// no answer at all, the module asked, with the modules that did answer
/// something. A module that answered nothing may only be asleep, as for a
/// while after the car is switched off; see `readCar`.
typedef ValuesRead = ({
  Map<String, double> values,
  Map<String, Unreported> unreported,
  Map<String, CanId> unanswered,
  Set<CanId> answered,
});
