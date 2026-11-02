import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings/settings.dart';
import '../core/vehicles/vehicle.dart';
import 'live_activity_state.dart';
import 'settings_state.dart';

/// The vehicle the app is about: the live one (in a session, or a trip
/// between connections), else the one the user picked, else the one seen
/// most recently. Home shows it, Vehicles marks it, and Developer tools
/// connects to it.
Vehicle? focusedVehicleFor({
  required AppSettings settings,
  String? liveId,
  String? pickedId,
}) {
  if (liveId case final live?) {
    if (settings.vehicleById(live) case final vehicle?) return vehicle;
  }
  if (pickedId case final picked?) {
    if (settings.vehicleById(picked) case final vehicle?) return vehicle;
  }
  return settings.mostRecentVehicle;
}

/// The vehicle in a session or a trip right now, if any.
final _liveVehicleIdProvider = Provider<String?>(
  (ref) => ref.watch(liveActivityProvider.select((live) => live.vehicleId)),
);

/// Whether there's more than one vehicle to choose between.
final canPickVehicleProvider = Provider<bool>(
  (ref) => ref.watch(
    appSettingsProvider.select((s) => (s.value?.vehicles.length ?? 0) > 1),
  ),
);

/// The vehicle the user picked. A car connecting clears it, so the app goes
/// back to following the car that connected last.
final focusPickProvider = NotifierProvider<FocusPick, String?>(FocusPick.new);

class FocusPick extends Notifier<String?> {
  @override
  String? build() {
    ref.listen(_liveVehicleIdProvider, (_, live) {
      if (live != null) state = null;
    });
    return null;
  }

  void pick(String vehicleId) => state = vehicleId;
}

final focusedVehicleProvider = Provider<Vehicle?>((ref) {
  final settings = ref.watch(appSettingsProvider).value;
  if (settings == null) return null;
  return focusedVehicleFor(
    settings: settings,
    liveId: ref.watch(_liveVehicleIdProvider),
    pickedId: ref.watch(focusPickProvider),
  );
});
