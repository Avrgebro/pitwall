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
  /// Neither do last values that couldn't be loaded: they're only shown,
  /// and the file they couldn't be read from isn't written over.
  Future<void> record(
    String vehicleId,
    Map<String, num> values,
    DateTime at, {
    required int seq,
  }) async {
    if (values.isEmpty) return;
    try {
      await (future, ref.read(appSettingsProvider.future)).wait;
    } on ParallelWaitError {
      return;
    }
    // Nothing is awaited from here to the change, so a delete can't fall
    // in between and be undone.
    final settings = ref.read(appSettingsProvider).requireValue;
    if (settings.vehicleById(vehicleId) == null) return;
    await _save(state.requireValue.record(vehicleId, values, at, seq: seq));
  }

  Future<void> _keepOnly(Set<String> vehicleIds) async {
    try {
      await future;
    } on Object {
      // Couldn't be loaded: nothing to keep, and nothing to write over.
      return;
    }
    final current = state.requireValue;
    final kept = current.only(vehicleIds);
    if (kept.byVehicle.length != current.byVehicle.length) await _save(kept);
  }

  /// Nothing awaits following the settings, so a failure is reported here.
  void _report(Object error, StackTrace stack) => FlutterError.reportError(
    FlutterErrorDetails(exception: error, stack: stack, library: 'last values'),
  );

  /// Writes to storage, one after another, so the file ends up with the
  /// newest values.
  Future<void> _writes = Future.value();

  /// Makes [values] current, then writes them; see
  /// `AppSettingsNotifier._save`.
  Future<void> _save(LastValues values) {
    state = AsyncData(values);
    final write = _writes.then((_) => _storage.save(values));
    _writes = write.then((_) {}, onError: (_) {});
    return write;
  }
}
