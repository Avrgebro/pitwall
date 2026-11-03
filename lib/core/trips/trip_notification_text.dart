import '../format/formatters.dart';
import '../vehicles/vehicle.dart';

/// What the trip's notification says at each stage.
abstract final class TripNotificationText {
  static String connecting(Vehicle vehicle) =>
      'Connecting to ${vehicle.adapter?.name ?? 'the adapter'}…';

  static String reading(Vehicle vehicle, Duration interval) =>
      'Reading ${vehicle.name} ${Formatters.every(interval)}';

  static String waitingForCar(Vehicle vehicle) =>
      'Waiting for ${vehicle.name} to answer';

  static const ending = 'Sending the last reading…';
}
