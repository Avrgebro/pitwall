import 'profile_ref.dart';
import 'signal_set.dart';

/// A vehicle's profile as found on the phone: none, one that can't be read
/// (its file is gone or no longer parses), or one that loaded.
sealed class StoredProfile {
  const StoredProfile();
}

final class NoProfile extends StoredProfile {
  const NoProfile();
}

final class UnreadableProfile extends StoredProfile {
  const UnreadableProfile(this.ref);

  /// The file the vehicle says it has.
  final ProfileRef ref;
}

final class LoadedProfile extends StoredProfile {
  const LoadedProfile(this.ref, this.signals);

  final ProfileRef ref;
  final SignalSet signals;
}
