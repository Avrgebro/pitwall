/// Which vehicle a trip is for, as named by whatever started it.
sealed class TripTarget {
  const TripTarget();

  /// Reads the channel arguments [toArguments] writes, as `TripTarget.kt`
  /// does. Anything else is a mistake in the bridge, and an error rather
  /// than a trip for any vehicle.
  static TripTarget fromArguments(Object? arguments) => switch (arguments) {
    {'kind': 'headUnit', 'address': final String address}
        when arguments.length == 2 =>
      HeadUnitTarget(address),
    {'kind': 'vehicle', 'id': final String id} when arguments.length == 2 =>
      VehicleTarget(id),
    {'kind': 'any'} when arguments.length == 1 => const AnyVehicleTarget(),
    _ => throw FormatException('Not a trip target', arguments),
  };

  /// How a target travels between Dart and Android: its `kind`, and what
  /// that kind names.
  Map<String, String> toArguments() => switch (this) {
    HeadUnitTarget(:final address) => {'kind': 'headUnit', 'address': address},
    VehicleTarget(:final id) => {'kind': 'vehicle', 'id': id},
    AnyVehicleTarget() => {'kind': 'any'},
  };
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
