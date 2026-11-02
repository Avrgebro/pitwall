import '../../core/vehicles/vehicle.dart';

/// What a vehicle needs, in words.
abstract final class VehicleNeedText {
  static String label(VehicleNeed need) => switch (need) {
    VehicleNeed.adapter => 'Choose its adapter',
    VehicleNeed.headUnit => 'Choose the car\'s Bluetooth for trip start',
    VehicleNeed.supportedTripStart => 'Its trip start isn\'t available yet',
  };
}
