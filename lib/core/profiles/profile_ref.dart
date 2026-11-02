import 'package:flutter/foundation.dart';

/// Which profile file a vehicle has: the name it was imported from, and
/// when. The file itself is kept by the settings store, by vehicle id.
@immutable
class ProfileRef {
  const ProfileRef(this.name, {this.importedAt});

  /// The file name it was imported from, such as `default.json`.
  final String name;

  /// When it was imported; unknown if that didn't survive in saved data.
  final DateTime? importedAt;

  @override
  bool operator ==(Object other) =>
      other is ProfileRef &&
      other.name == name &&
      other.importedAt == importedAt;

  @override
  int get hashCode => Object.hash(name, importedAt);
}
