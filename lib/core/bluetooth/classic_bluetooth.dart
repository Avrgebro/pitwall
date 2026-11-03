import 'dart:typed_data';

import '../platform/messages.g.dart';
import 'adapter_type.dart';
import 'bluetooth_gateway.dart';
import 'device_kind.dart';

/// Classic Bluetooth (serial) adapters, Android only. Backed by
/// `ClassicBluetoothChannel.kt` and `BluetoothStateChannel.kt`, through the
/// messages in `pigeons/messages.dart`.
///
/// Errors surface as `PlatformException` with codes `unavailable`,
/// `disabled`, `permission`, `connect_failed` or `write_failed`.
class ClassicBluetoothGateway implements BluetoothGateway {
  ClassicBluetoothGateway();

  final _api = ClassicBluetoothApi();

  /// One stream each for the life of the gateway: each call opens a new
  /// channel.
  late final _input = adapterInput();
  @override
  late final Stream<bool> enabled = bluetoothEnabled();

  @override
  Future<List<BondedDevice>> bondedDevices() async => [
    for (final device in await _api.bondedDevices())
      BondedDevice(
        name: device.name,
        address: device.address,
        kind: DeviceKind.fromClass(device.deviceClass),
        type: AdapterType.classic,
      ),
  ];

  /// Opens a serial connection to the adapter at [address]. Only one
  /// connection is open at a time; connecting again closes the previous one.
  @override
  Future<ClosableTransport> connect(String address) async {
    await _api.connect(address);
    return _ClassicTransport(this);
  }
}

class _ClassicTransport implements ClosableTransport {
  _ClassicTransport(this._gateway);

  final ClassicBluetoothGateway _gateway;

  /// Ends with an error when the adapter disconnects.
  @override
  Stream<List<int>> get input => _gateway._input;

  @override
  Future<void> write(List<int> bytes) =>
      _gateway._api.write(Uint8List.fromList(bytes));

  @override
  Future<void> close() => _gateway._api.disconnect();
}
