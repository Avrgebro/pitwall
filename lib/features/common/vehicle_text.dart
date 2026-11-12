import '../../core/vehicles/vehicle.dart';

/// What a vehicle needs, in words.
extension VehicleNeedText on VehicleNeed {
  String get label => switch (this) {
    VehicleNeed.adapter => 'Choose its adapter',
    VehicleNeed.headUnit => 'Choose the car\'s Bluetooth for trip start',
    VehicleNeed.bluetoothLeAdapter =>
      'Choose a Bluetooth LE adapter, or another trip start',
    VehicleNeed.adapterWatch => 'Let Android watch for its adapter',
  };
}
