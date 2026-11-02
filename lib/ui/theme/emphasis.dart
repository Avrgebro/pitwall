/// How strongly a tinted element, such as a chip or an icon badge, shows
/// its tone.
enum Emphasis {
  /// Solid accent background, for the main state (Running).
  filled,

  /// Soft tone background (Connecting, 3 queued).
  tonal,

  /// Border only, for quiet states (Waiting for the car).
  outlined,
}
