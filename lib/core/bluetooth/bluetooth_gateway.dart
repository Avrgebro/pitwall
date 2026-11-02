import 'package:flutter/services.dart';

import '../obd/obd_transport.dart';
import 'classic_bluetooth.dart';

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

/// A transport the app can close when it's done.
abstract interface class ClosableTransport implements ObdTransport {
  Future<void> close();
}

/// Classic Bluetooth (serial) adapters, Android only.
class ClassicBluetoothGateway implements BluetoothGateway {
  const ClassicBluetoothGateway();

  @override
  Future<List<BondedDevice>> bondedDevices() =>
      ClassicBluetooth.bondedDevices();

  @override
  Future<ClosableTransport> connect(String address) =>
      ClassicBluetooth.connect(address);

  static const _state = EventChannel('pitwall/bluetooth_state');

  /// Backed by `BluetoothStateChannel.kt`.
  @override
  Stream<bool> get enabled =>
      _state.receiveBroadcastStream().map((on) => on as bool);
}
