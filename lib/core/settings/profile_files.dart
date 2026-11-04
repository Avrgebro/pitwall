import 'dart:io';

import '../profiles/profile_ref.dart';
import '../profiles/signal_set.dart';
import '../profiles/stored_profile.dart';
import '../storage/app_files.dart';
import '../vehicles/vehicle.dart';
import 'settings.dart';

/// Each vehicle's imported profiles, as files in the app's private storage:
/// one per import, named by [fileName], so the settings always name
/// exactly the file they mean.
class ProfileFiles {
  const ProfileFiles();

  /// The vehicle's imported profile, as found on the phone. A file that's
  /// gone, can't be read, or no longer parses is an [UnreadableProfile].
  Future<StoredProfile> load(Vehicle vehicle) async {
    final ref = vehicle.profile;
    if (ref == null) return const NoProfile();
    try {
      final file = await appFile(fileName(vehicle.id, ref));
      return LoadedProfile(ref, SignalSet.parse(await file.readAsString()));
    } on FileSystemException {
      return UnreadableProfile(ref);
    } on FormatException {
      return UnreadableProfile(ref);
    }
  }

  /// Saves [profile] as the file [ref] names for the vehicle. Only a
  /// parsed profile can be saved, so the file always holds one.
  Future<void> save(String vehicleId, ProfileRef ref, SignalSet profile) async {
    final file = await appFile(fileName(vehicleId, ref));
    await file.parent.create(recursive: true);
    await writeAtomically(file, profile.source);
  }

  /// Deletes the file [ref] names for the vehicle, if it's there.
  Future<void> delete(String vehicleId, ProfileRef ref) async {
    final file = await appFile(fileName(vehicleId, ref));
    if (await file.exists()) await file.delete();
  }

  /// Deletes every profile file the vehicle has.
  Future<void> deleteAll(String vehicleId) async {
    final legacy = await appFile('profiles/$vehicleId.json');
    if (await legacy.exists()) await legacy.delete();
    final folder = Directory((await appFile('profiles/$vehicleId')).path);
    if (await folder.exists()) await folder.delete(recursive: true);
  }

  /// Where the profile [ref] names is kept: a file per import, so the
  /// settings always name exactly the file they mean, and the one they
  /// named before is still there until they're saved. A profile from
  /// before import times were kept has the vehicle's one file.
  static String fileName(String vehicleId, ProfileRef ref) =>
      switch (ref.importedAt) {
        final at? =>
          'profiles/$vehicleId/${at.toUtc().microsecondsSinceEpoch}.json',
        null => 'profiles/$vehicleId.json',
      };

  /// Puts each vehicle's profile files in order, one vehicle at a time:
  /// a profile kept in its vehicle's one file, from before each import had
  /// its own, moves to the name its settings now give it ([fileName]);
  /// files they don't name, as left by a crash or a delete that failed, go.
  /// One vehicle's trouble leaves its files as they are, and its profile
  /// then reads as unreadable, not every vehicle's.
  ///
  /// What fails is handed to [report], with what was being done.
  Future<void> tidy(
    AppSettings settings, {
    required Future<void> Function(String what, Future<void> Function() action)
    report,
  }) async {
    for (final vehicle in settings.vehicles) {
      await report(
        'putting the profile files of ${vehicle.id} in order',
        () => _tidy(vehicle),
      );
    }
    // A vehicle that's gone keeps nothing, as when its delete failed.
    await report('removing the profiles of vehicles that are gone', () async {
      final profiles = Directory((await appFile('profiles')).path);
      if (!await profiles.exists()) return;
      final ids = {for (final vehicle in settings.vehicles) vehicle.id};
      await for (final entry in profiles.list()) {
        final name = entry.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
        if (!ids.contains(name.replaceAll(RegExp(r'\.json$'), ''))) {
          await entry.delete(recursive: true);
        }
      }
    });
  }

  Future<void> _tidy(Vehicle vehicle) async {
    final ref = vehicle.profile;
    final legacy = await appFile('profiles/${vehicle.id}.json');
    final folder = Directory((await appFile('profiles/${vehicle.id}')).path);
    final named = ref == null ? null : await appFile(fileName(vehicle.id, ref));
    if (named != null && named.path != legacy.path && await legacy.exists()) {
      if (await named.exists()) {
        await legacy.delete();
      } else {
        await named.parent.create(recursive: true);
        await legacy.rename(named.path);
      }
    }
    if (named?.path != legacy.path && await legacy.exists()) {
      await legacy.delete();
    }
    if (!await folder.exists()) return;
    await for (final entry in folder.list()) {
      if (entry is File && entry.path != named?.path) await entry.delete();
    }
  }
}
