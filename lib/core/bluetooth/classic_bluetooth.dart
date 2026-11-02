import 'package:flutter/services.dart';

import 'bluetooth_gateway.dart';
import 'device_kind.dart';

/// Classic Bluetooth (serial) adapters, Android only. Backed by
/// `ClassicBluetoothChannel.kt` and `BluetoothStateChannel.kt`.
///
/// Errors surface as [PlatformException] with codes `unavailable`,
/// `disabled`, `permission`, `connect_failed` or `write_failed`.
class ClassicBluetoothGateway implements BluetoothGateway {
  const ClassicBluetoothGateway();

  static const _methods = MethodChannel('pitwall/classic_bluetooth');
  static const _input = EventChannel('pitwall/classic_bluetooth/input');
  static const _state = EventChannel('pitwall/bluetooth_state');

  @override
  Future<List<BondedDevice>> bondedDevices() async {
    final devices = await _methods.invokeListMethod<Map>('bondedDevices');
    return [
      for (final device in devices ?? const <Map>[])
        BondedDevice(
          name: device['name'] as String,
          address: device['address'] as String,
          kind: DeviceKind.fromClass(device['deviceClass'] as int),
        ),
    ];
  }

  /// Opens a serial connection to the adapter at [address]. Only one
  /// connection is open at a time; connecting again closes the previous one.
  @override
  Future<ClosableTransport> connect(String address) async {
    await _methods.invokeMethod<void>('connect', {'address': address});
    return _ClassicTransport();
  }

  @override
  Stream<bool> get enabled =>
      _state.receiveBroadcastStream().map((on) => on as bool);
}

class _ClassicTransport implements ClosableTransport {
  /// Ends with an error when the adapter disconnects.
  @override
  late final Stream<List<int>> input = ClassicBluetoothGateway._input
      .receiveBroadcastStream()
      .map((bytes) => bytes as Uint8List);

  @override
  Future<void> write(List<int> bytes) => ClassicBluetoothGateway._methods
      .invokeMethod<void>('write', Uint8List.fromList(bytes));

  @override
  Future<void> close() =>
      ClassicBluetoothGateway._methods.invokeMethod<void>('disconnect');
}
