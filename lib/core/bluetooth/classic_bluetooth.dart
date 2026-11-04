import 'dart:async';

import 'package:flutter/services.dart';

import '../obd/obd_transport.dart';
import '../platform/messages.g.dart';
import 'adapter_type.dart';
import 'bluetooth_gateway.dart';
import 'device_kind.dart';

/// Classic Bluetooth (serial) adapters, Android only. Backed by
/// `ClassicBluetoothChannel.kt` and `BluetoothStateChannel.kt`, through the
/// messages in `pigeons/messages.dart`.
///
/// Errors surface as [PlatformException] with codes `unavailable`,
/// `disabled`, `permission` or `connect_failed`.
class ClassicBluetoothGateway implements BluetoothGateway {
  ClassicBluetoothGateway();

  final _api = ClassicBluetoothApi();

  /// One stream each for the life of the gateway: each call opens a new
  /// channel.
  late final _events = adapterEvents();
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

  /// Connection numbers, never reused, even after Dart restarts while
  /// Android carries on: they start from the time the gateway is made.
  int _lastConnection = DateTime.now().microsecondsSinceEpoch;

  /// Starts a serial connection to the adapter at [address]. Its number
  /// is chosen here, before anything is sent, so it can be closed while
  /// Android is still connecting.
  @override
  AdapterConnection connect(String address) =>
      _ClassicConnection(this, ++_lastConnection, address);
}

class _ClassicConnection implements AdapterConnection {
  _ClassicConnection(this._gateway, this._number, String address) {
    opened = _open(address);
  }

  final ClassicBluetoothGateway _gateway;
  final int _number;

  @override
  late final Future<ObdTransport> opened;

  Future<ObdTransport> _open(String address) async {
    await _gateway._api.connect(_number, address);
    return _ClassicTransport(_gateway, _number);
  }

  @override
  Future<void> close() => _gateway._api.disconnect(_number);
}

/// One serial connection, by its number: writing or closing reaches only
/// it, and its input holds only its own bytes.
class _ClassicTransport implements ObdTransport {
  _ClassicTransport(this._gateway, this._connection);

  final ClassicBluetoothGateway _gateway;
  final int _connection;

  /// Ends when the adapter drops the connection.
  @override
  late final Stream<List<int>> input = _gateway._events
      .where(
        (event) => switch (event) {
          AdapterBytes(:final connection) ||
          AdapterDropped(:final connection) => connection == _connection,
        },
      )
      .takeWhile((event) => event is! AdapterDropped)
      .map((event) => (event as AdapterBytes).bytes);

  @override
  Future<void> write(List<int> bytes) async {
    try {
      await _gateway._api.write(_connection, Uint8List.fromList(bytes));
    } on PlatformException {
      throw const TransportClosed();
    }
  }
}
