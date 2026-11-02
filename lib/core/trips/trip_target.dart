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

/// The app asked for a trip for one vehicle.
final class VehicleTarget extends TripTarget {
  const VehicleTarget(this.id);

  final String id;
}

/// The app asked for a trip for whichever vehicle's adapter answers.
final class AnyVehicleTarget extends TripTarget {
  const AnyVehicleTarget();
}
