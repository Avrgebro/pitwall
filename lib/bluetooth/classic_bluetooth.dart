import 'package:flutter/services.dart';

import '../obd/obd_transport.dart';

/// A device paired with the phone in Android's Bluetooth settings.
class BondedDevice {
  const BondedDevice({required this.name, required this.address});

  final String name;
  final String address;
}

/// Classic Bluetooth (serial) adapters, Android only. Backed by
/// `ClassicBluetoothChannel.kt`.
///
/// Errors surface as [PlatformException] with codes `unavailable`,
/// `disabled`, `permission`, `connect_failed` or `write_failed`.
abstract final class ClassicBluetooth {
  static const _methods = MethodChannel('pitwall/classic_bluetooth');
  static const _input = EventChannel('pitwall/classic_bluetooth/input');

  static Future<List<BondedDevice>> bondedDevices() async {
    final devices = await _methods.invokeListMethod<Map>('bondedDevices');
    return [
      for (final device in devices ?? const <Map>[])
        BondedDevice(
          name: device['name'] as String,
          address: device['address'] as String,
        ),
    ];
  }

  /// Opens a serial connection to the adapter at [address]. Only one
  /// connection is open at a time; connecting again closes the previous one.
  static Future<ClassicTransport> connect(String address) async {
    await _methods.invokeMethod<void>('connect', {'address': address});
    return ClassicTransport._();
  }
}

class ClassicTransport implements ObdTransport {
  ClassicTransport._();

  /// Ends with an error when the adapter disconnects.
  @override
  late final Stream<List<int>> input = ClassicBluetooth._input
      .receiveBroadcastStream()
      .map((bytes) => bytes as Uint8List);

  @override
  Future<void> write(List<int> bytes) => ClassicBluetooth._methods
      .invokeMethod<void>('write', Uint8List.fromList(bytes));

  Future<void> close() =>
      ClassicBluetooth._methods.invokeMethod<void>('disconnect');
}
