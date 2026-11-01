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

  /// The title of a row in a list.
  TextStyle get rowTitle => (titleMedium ?? const TextStyle()).copyWith(
    fontSize: 17,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  /// The line under a row's title.
  TextStyle get rowSubtitle =>
      (bodyMedium ?? const TextStyle()).copyWith(fontSize: 15, height: 1.35);
}
