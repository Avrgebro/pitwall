import '../obd/obd_transport.dart';
import 'adapter_type.dart';
import 'device_kind.dart';

/// Access to the phone's Bluetooth, behind an interface so screens and
/// controllers can be tested without a phone.
abstract interface class BluetoothGateway {
  /// Devices paired in Android's Bluetooth settings.
  Future<List<BluetoothDevice>> bondedDevices();

  /// Bluetooth LE devices nearby, each as it's found, for as long as the
  /// stream is listened to: scanning stops when it's cancelled. Devices
  /// without a name are left out.
  Stream<BluetoothDevice> nearbyDevices();

  /// Starts connecting to the adapter at [address], of [type]. Connecting
  /// again over the same kind of Bluetooth closes that kind's previous
  /// connection; one over the other kind stays open until it's closed.
  AdapterConnection connect(String address, AdapterType type);

  /// Whether Bluetooth is on: the current state, then each change.
  Stream<bool> get enabled;
}

/// A Bluetooth device the phone knows of: one paired in Android's
/// Bluetooth settings, or a Bluetooth LE one found nearby, which needs no
/// pairing.
class BluetoothDevice {
  const BluetoothDevice({
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
