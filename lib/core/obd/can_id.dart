/// An 11-bit CAN id, written as three hex digits like `7E0`: where a
/// request goes, or where its reply comes from. Being one is checked once,
/// where it's read, so it's safe to put in an adapter command.
extension type const CanId._(String hex) {
  static final _pattern = RegExp(r'^[0-9A-F]{3}$');

  /// The functional address every OBD-II module listens on.
  static const broadcast = CanId._('7DF');

  /// [text] as a CAN id, or null if it isn't one, such as a 29-bit id.
  static CanId? tryParse(String text) {
    final upper = text.toUpperCase();
    return _pattern.hasMatch(upper) ? CanId._(upper) : null;
  }
}
