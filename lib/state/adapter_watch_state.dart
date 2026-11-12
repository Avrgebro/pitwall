import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/vehicles/vehicle.dart';
import 'infrastructure.dart';
import 'settings_state.dart';

/// The Bluetooth LE adapters Android can watch for, as Android says: the
/// ones the user confirmed and hasn't removed since, in system settings or
/// by reinstalling. Refreshed when the app comes back to the foreground,
/// and after the user confirms one. Not known yet while loading, or when
/// Android couldn't say.
final watchableAdaptersProvider =
    AsyncNotifierProvider<WatchableAdaptersNotifier, Set<String>>(
      WatchableAdaptersNotifier.new,
      retry: (_, _) => null,
    );

class WatchableAdaptersNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    try {
      return {
        for (final address
            in await ref.read(tripServiceGatewayProvider).watchableAdapters())
          address.toUpperCase(),
      };
    } on Object catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'trips',
          context: ErrorDescription('while asking which adapters are watched'),
        ),
      );
      rethrow;
    }
  }

  /// Asks Android again.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future.then((_) {}, onError: (_) {});
  }
}

/// What the vehicle lacks before it works on its own, with Android's word
/// on whether it can watch for the adapter; see [Vehicle.needs].
final vehicleNeedsProvider = Provider.family<List<VehicleNeed>, String>((
  ref,
  id,
) {
  final vehicle = ref.watch(vehicleProvider(id));
  if (vehicle == null) return const [];
  return vehicle.needs(watchable: ref.watch(watchableAdaptersProvider).value);
});
