import '../../core/vehicles/vehicle.dart';

/// How a vehicle's trips start, in words.
abstract final class TripStartText {
  /// "When TUCSON BT connects", or what's missing.
  static ({String text, bool problem}) summary(Vehicle vehicle) =>
      switch (vehicle.tripStart) {
        TripStart.carBluetooth => switch (vehicle.headUnitName) {
          final name? => (text: 'When $name connects', problem: false),
          null => (text: 'Choose the car\'s Bluetooth', problem: true),
        },
        TripStart.drivingDetection => (
          text: 'When driving is detected (not available yet)',
          problem: true,
        ),
      };
}
