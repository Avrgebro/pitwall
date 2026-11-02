import '../../core/bluetooth/adapter_type.dart';
import '../../core/vehicles/vehicle.dart';

/// How an adapter connects, in words.
extension AdapterTypeText on AdapterType {
  String get label => switch (this) {
    AdapterType.classic => 'Classic',
    AdapterType.ble => 'Bluetooth LE',
  };
}

/// What a vehicle needs, in words.
extension VehicleNeedText on VehicleNeed {
  String get label => switch (this) {
    VehicleNeed.adapter => 'Choose its adapter',
    VehicleNeed.headUnit => 'Choose the car\'s Bluetooth for trip start',
    VehicleNeed.supportedTripStart => 'Its trip start isn\'t available yet',
  };
}
