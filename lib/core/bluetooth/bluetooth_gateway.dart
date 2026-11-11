import '../obd/obd_transport.dart';
import 'adapter_type.dart';
import 'device_kind.dart';

/// Access to the phone's Bluetooth, behind an interface so screens and
/// controllers can be tested without a phone.
abstract interface class BluetoothGateway {
  /// Devices paired in Android's Bluetooth settings.
  Future<List<BondedDevice>> bondedDevices();

  /// Starts connecting to the adapter at [address], of [type]. Only one
  /// connection is open at a time: connecting again closes the previous
  /// one.
  AdapterConnection connect(String address, AdapterType type);

  /// Whether Bluetooth is on: the current state, then each change.
  Stream<bool> get enabled;
}

/// A device paired with the phone in Android's Bluetooth settings.
class BondedDevice {
  const BondedDevice({
    required this.name,
    required this.address,
    this.kind = DeviceKind.uncategorized,
    required this.type,
  });

  final String name;
  final String address;
  final DeviceKind kind;

  /// How the phone talks to it, if it's an adapter.
  final AdapterType type;
}

/// One connection to an adapter, from the moment it's asked for, so it can
/// be closed at any stage.
abstract interface class AdapterConnection {
  /// The transport, once connected. Fails with a `PlatformException` if
  /// the adapter can't be reached, or if [close] came first.
  Future<ObdTransport> get opened;

  /// Closes the connection, stopping a connect still under way.
  Future<void> close();
}
