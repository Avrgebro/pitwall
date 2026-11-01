import 'package:material_ui/material_ui.dart';

/// Text styles beyond the Material type scale.
extension AppTextStyles on TextTheme {
  /// Payload keys, addresses and raw adapter traffic.
  TextStyle get mono =>
      (bodySmall ?? const TextStyle()).copyWith(fontFamily: 'monospace');

  /// The big number in a value tile.
  TextStyle get value => (headlineMedium ?? const TextStyle()).copyWith(
    fontWeight: FontWeight.w400,
    height: 1.1,
  );

  /// The unit next to a value, deliberately stepped back.
  TextStyle get valueUnit =>
      (titleSmall ?? const TextStyle()).copyWith(fontWeight: FontWeight.w400);
}
