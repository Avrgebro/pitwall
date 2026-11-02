import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/readings/last_values.dart';
import 'infrastructure.dart';

/// The last value of each key every vehicle reported, kept across
/// restarts. Home shows a vehicle's from here.
final lastValuesProvider =
    AsyncNotifierProvider<LastValuesNotifier, LastValues>(
      LastValuesNotifier.new,
    );

class LastValuesNotifier extends AsyncNotifier<LastValues> {
  LastValuesStorage get _storage => ref.read(lastValuesStorageProvider);

  @override
  Future<LastValues> build() => _storage.load();

  Future<void> record(
    String vehicleId,
    Map<String, num> values,
    DateTime at,
  ) async {
    if (values.isEmpty) return;
    await _save((await future).record(vehicleId, values, at));
  }

  Future<void> forget(String vehicleId) async =>
      _save((await future).without(vehicleId));

  Future<void> _save(LastValues values) async {
    state = AsyncData(values);
    await _storage.save(values);
  }
}
