import 'dart:async';

import 'package:flutter/services.dart';

import '../obd/obd_transport.dart';
import '../platform/messages.g.dart';
import 'adapter_type.dart';
import 'bluetooth_gateway.dart';
import 'device_kind.dart';

/// Android's Bluetooth: classic (serial) and Bluetooth LE adapters. Backed
/// by `ClassicBluetoothChannel.kt`, `BleChannel.kt` and
/// `BluetoothStateChannel.kt`, through the messages in
/// `pigeons/messages.dart`.
///
/// Errors surface as [PlatformException] with codes `unavailable`,
/// `disabled`, `permission` or `connect_failed`.
class AndroidBluetoothGateway implements BluetoothGateway {
  AndroidBluetoothGateway();

  final _classic = ClassicBluetoothApi();
  final _ble = BleApi();

  /// One stream each for the life of the gateway: each call opens a new
  /// channel.
  late final _events = adapterEvents();
  @override
  late final Stream<bool> enabled = bluetoothEnabled();

  @override
  Future<List<BondedDevice>> bondedDevices() async => [
    for (final device in await _classic.bondedDevices())
      BondedDevice(
        name: device.name,
        address: device.address,
        kind: DeviceKind.fromClass(device.deviceClass),
        type: AdapterType.classic,
      ),
  ];

  /// Connection numbers, which only go up, even after Dart restarts while
  /// Android carries on: they start from the time the gateway is made.
  int _lastConnection = DateTime.now().microsecondsSinceEpoch;

  /// Starts a connection to the adapter at [address], over classic
  /// Bluetooth or Bluetooth LE as its [type] says. Its number is chosen
  /// here, before anything is sent, so it can be closed while Android is
  /// still connecting. Numbers are shared by both kinds, so they never
  /// meet in the one stream of events.
  @override
  AdapterConnection connect(String address, AdapterType type) =>
      _Connection(this, ++_lastConnection, address, switch (type) {
        AdapterType.classic => (
          connect: _classic.connect,
          write: _classic.write,
          disconnect: _classic.disconnect,
        ),
        AdapterType.ble => (
          connect: _ble.connect,
          write: _ble.write,
          disconnect: _ble.disconnect,
        ),
      });
}

/// The calls a kind of adapter connection takes, by connection number.
typedef _Calls = ({
  Future<void> Function(int connection, String address) connect,
  Future<void> Function(int connection, Uint8List bytes) write,
  Future<void> Function(int connection) disconnect,
});

class _Connection implements AdapterConnection {
  _Connection(this._gateway, this._number, String address, this._calls) {
    // Started at once, so its number is in use from now. Its failure goes
    // to whoever awaits it; closed without awaiting, nobody needs to hear.
    opened = _open(address)..ignore();
  }

  final AndroidBluetoothGateway _gateway;
  final int _number;
  final _Calls _calls;

  @override
  late final Future<ObdTransport> opened;

  Future<ObdTransport> _open(String address) async {
    await _calls.connect(_number, address);
    return _Transport(_gateway, _number, _calls);
  }

  @override
  Future<void> close() => _calls.disconnect(_number);
}

/// One connection, by its number: writing or closing reaches only it, and
/// its input holds only its own bytes.
class _Transport implements ObdTransport {
  _Transport(this._gateway, this._connection, this._calls);

  final AndroidBluetoothGateway _gateway;
  final int _connection;
  final _Calls _calls;

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
      await _calls.write(_connection, Uint8List.fromList(bytes));
    } on PlatformException {
      throw const TransportClosed();
    }
  }
}
