import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings/settings.dart';
import '../core/vehicles/vehicle.dart';
import 'session_state.dart';
import 'settings_state.dart';

/// The vehicle Home shows: the one in a live session, else the one the
/// user picked, else the one seen most recently.
Vehicle? homeVehicleFor({
  required AppSettings settings,
  required SessionState session,
  String? pickedId,
}) {
  if (session.vehicleId case final live?) {
    if (settings.vehicleById(live) case final vehicle?) return vehicle;
  }
  if (pickedId case final picked?) {
    if (settings.vehicleById(picked) case final vehicle?) return vehicle;
  }
  return settings.mostRecentVehicle;
}

/// The vehicle the user picked to see on Home. A car connecting clears it,
/// so Home goes back to following the car that connected last.
final homePickProvider = NotifierProvider<HomePick, String?>(HomePick.new);

class HomePick extends Notifier<String?> {
  @override
  String? build() {
    ref.listen(sessionProvider.select((session) => session.vehicleId), (
      _,
      live,
    ) {
      if (live != null) state = null;
    });
    return null;
  }

  void pick(String vehicleId) => state = vehicleId;
}

/// The vehicle Home shows, and that Vehicles marks "On Home".
final homeVehicleProvider = Provider<Vehicle?>((ref) {
  final settings = ref.watch(appSettingsProvider).value;
  if (settings == null) return null;
  return homeVehicleFor(
    settings: settings,
    session: ref.watch(sessionProvider),
    pickedId: ref.watch(homePickProvider),
  );
});
