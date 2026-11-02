import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/readings/last_values.dart';
import 'infrastructure.dart';
import 'settings_state.dart';

/// The last value of each key every vehicle reported, kept across
/// restarts. Home shows a vehicle's from here. Follows the settings, so a
/// deleted vehicle's values go with it.
final lastValuesProvider =
    AsyncNotifierProvider<LastValuesNotifier, LastValues>(
      LastValuesNotifier.new,
    );

class LastValuesNotifier extends AsyncNotifier<LastValues> {
  LastValuesStorage get _storage => ref.read(lastValuesStorageProvider);

  @override
  Future<LastValues> build() {
    ref.listen(appSettingsProvider, (_, settings) {
      if (settings.value case final settings?) {
        unawaited(
          _keepOnly({for (final v in settings.vehicles) v.id})
              .catchError(_report),
        );
      }
    }, fireImmediately: true);
    return _storage.load();
  }

  /// Keeps [values], read [at], as sent in the reading numbered [seq].
  /// A vehicle deleted meanwhile, say as its reading came in, keeps none.
  Future<void> record(
    String vehicleId,
    Map<String, num> values,
    DateTime at, {
    int? seq,
  }) async {
    if (values.isEmpty) return;
    final settings = await ref.read(appSettingsProvider.future);
    if (settings.vehicleById(vehicleId) == null) return;
    await _save((await future).record(vehicleId, values, at, seq: seq));
  }

  Future<void> _keepOnly(Set<String> vehicleIds) async {
    final current = await future;
    final kept = current.only(vehicleIds);
    if (kept.byVehicle.length != current.byVehicle.length) await _save(kept);
  }

  /// Nothing awaits following the settings, so a failure is reported here.
  void _report(Object error, StackTrace stack) => FlutterError.reportError(
    FlutterErrorDetails(exception: error, stack: stack, library: 'last values'),
  );

  Future<void> _save(LastValues values) async {
    state = AsyncData(values);
    await _storage.save(values);
  }
}
