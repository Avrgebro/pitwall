import '../../core/vehicles/vehicle.dart';

/// How a vehicle's trips start, in words.
abstract final class TripStartText {
  /// "When TUCSON BT connects", or what's missing.
  static ({String text, bool problem}) summary(Vehicle vehicle) {
    final problem = vehicle.needs.any((need) => need.isTripStart);
    final text = switch ((vehicle.tripStart, vehicle.headUnit)) {
      (TripStart.carBluetooth, final headUnit?) when !problem =>
        'When ${headUnit.name} connects',
      (TripStart.carBluetooth, _) => 'Choose the car\'s Bluetooth',
      (TripStart.adapterWakes, _) when !problem =>
        'When ${vehicle.adapter?.name ?? 'the adapter'} wakes',
      (TripStart.adapterWakes, _) =>
        'When the adapter wakes: confirm it with Android',
    };
    return (text: text, problem: problem);
  }
}
