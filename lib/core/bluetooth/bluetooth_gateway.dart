import '../obd/obd_transport.dart';
import 'adapter_type.dart';
import 'device_kind.dart';

/// Access to the phone's Bluetooth, behind an interface so screens and
/// controllers can be tested without a phone.
abstract interface class BluetoothGateway {
  /// Devices paired in Android's Bluetooth settings.
  Future<List<BondedDevice>> bondedDevices();

  /// Opens a connection to the adapter at [address].
  Future<ClosableTransport> connect(String address);

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

/// A transport the app can close when it's done.
abstract interface class ClosableTransport implements ObdTransport {
  Future<void> close();
}
