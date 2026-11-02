import '../../core/vehicles/vehicle.dart';

/// How a vehicle's trips start, in words.
abstract final class TripStartText {
  /// "When TUCSON BT connects", or what's missing.
  static ({String text, bool problem}) summary(Vehicle vehicle) {
    final problem = vehicle.needs.any((need) => need.isTripStart);
    final text = switch (vehicle.tripStart) {
      TripStart.carBluetooth when problem => 'Choose the car\'s Bluetooth',
      TripStart.carBluetooth =>
        'When ${vehicle.headUnitName ?? vehicle.headUnitAddress} connects',
      TripStart.drivingDetection =>
        'When driving is detected (not available yet)',
    };
    return (text: text, problem: problem);
  }
}
