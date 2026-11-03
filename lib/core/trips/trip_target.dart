/// Which vehicle a trip is for, as named by whatever started it.
sealed class TripTarget {
  const TripTarget();
}

/// A car's head unit connected: the trip is for the vehicle whose trips it
/// starts.
final class HeadUnitTarget extends TripTarget {
  const HeadUnitTarget(this.address);

  final String address;
}

/// What the app can ask for: one vehicle, or any. Only a head unit names
/// itself.
sealed class AppTripTarget extends TripTarget {
  const AppTripTarget();
}

/// The app asked for a trip for one vehicle.
final class VehicleTarget extends AppTripTarget {
  const VehicleTarget(this.id);

  final String id;
}

/// The app asked for a trip for whichever vehicle's adapter answers.
final class AnyVehicleTarget extends AppTripTarget {
  const AnyVehicleTarget();
}
