import 'package:flutter/foundation.dart';

/// Whether a longer list shows, and whether there's a row to fold it: the
/// list can be forced open, as while searching, or open or closed by the
/// user.
@immutable
class Disclosure {
  const Disclosure({required this.forced, required this.open});

  /// Shown with no row to fold it, so nothing it holds is hidden.
  final bool forced;

  /// Opened by the user.
  final bool open;

  bool get showsToggle => !forced;
  bool get showsList => forced || open;
}
