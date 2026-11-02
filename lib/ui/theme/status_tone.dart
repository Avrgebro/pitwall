/// The meaning a status carries, which decides its colours.
enum StatusTone {
  /// Plain information, no particular state.
  neutral,

  /// Something is happening right now (running, connected).
  active,

  /// All good (delivered, allowed).
  healthy,

  /// Worth knowing, nothing to do (queued, no signal).
  warning,

  /// Needs the user (refused, failing).
  error,
}
