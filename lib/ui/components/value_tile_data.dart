import 'package:flutter/foundation.dart';

/// One value to show in a [ValueGrid].
@immutable
class ValueTileData {
  const ValueTileData({
    required this.label,
    required this.value,
    this.unit,
    this.note,
  });

  final String label;

  /// The formatted value, or null if the car didn't report it.
  final String? value;
  final String? unit;

  /// A short line under the value, such as when it was read.
  final String? note;
}
