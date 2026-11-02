import 'signal_set.dart';

/// A vehicle's profile as found on the phone: none, one that can't be read
/// (its file is gone or no longer parses), or one that loaded.
sealed class StoredProfile {
  const StoredProfile();

  /// The parsed profile, when it loaded.
  SignalSet? get signals => null;
}

final class NoProfile extends StoredProfile {
  const NoProfile();
}

final class UnreadableProfile extends StoredProfile {
  const UnreadableProfile(this.fileName);

  /// The file the vehicle says it has.
  final String fileName;
}

final class LoadedProfile extends StoredProfile {
  const LoadedProfile(this.signals);

  @override
  final SignalSet signals;
}
