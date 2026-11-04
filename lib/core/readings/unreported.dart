/// Why a value that was asked for isn't in a reading.
enum Unreported {
  /// A standard value the car doesn't list among the ones it supports, so
  /// it isn't asked for.
  unsupported,

  /// Nothing answered the request, or the car refused it.
  noAnswer,

  /// The car answered, but its reply is too short to hold the value.
  notInReply,

  /// The car marked it as unavailable, or it was outside its valid range.
  unavailable,
}

/// What a read found: the values, and why each other one asked for isn't
/// among them.
typedef ValuesRead = ({
  Map<String, double> values,
  Map<String, Unreported> unreported,
});
