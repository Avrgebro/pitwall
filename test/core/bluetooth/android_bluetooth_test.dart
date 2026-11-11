import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/bluetooth/adapter_type.dart';
import 'package:pitwall/core/bluetooth/android_bluetooth.dart';
import 'package:pitwall/core/obd/obd_transport.dart';
import 'package:pitwall/core/platform/messages.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const api = 'dev.flutter.pigeon.pitwall.ClassicBluetoothApi';
  const ble = 'dev.flutter.pigeon.pitwall.BleApi';
  const codec = ClassicBluetoothApi.pigeonChannelCodec;

  late List<String> calls;
  late List<int> numbers;
  late StreamController<AdapterEvent> events;
  var writesFail = false;

  /// Holds Android's answer to connect until it completes.
  Completer<void>? connecting;

  void answer(
    String method,
    FutureOr<Object?> Function(List<Object?> args) reply, {
    String on = api,
  }) => messenger.setMockMessageHandler('$on.$method', (data) async {
    final args = codec.decodeMessage(data)! as List<Object?>;
    return codec.encodeMessage(await reply(args));
  });

  setUp(() {
    calls = [];
    numbers = [];
    writesFail = false;
    connecting = null;
    events = StreamController<AdapterEvent>.broadcast();
    answer('connect', (args) async {
      final number = args[0]! as int;
      numbers.add(number);
      calls.add('connect $number');
      await connecting?.future;
      // Like Android: closed before it opened, it doesn't open.
      return calls.contains('disconnect $number')
          ? ['connect_failed', 'Disconnected while connecting', null]
          : [null];
    });
    answer('write', (args) {
      calls.add('write ${args[0]}');
      return writesFail ? ['write_failed', 'Gone', null] : [null];
    });
    answer('disconnect', (args) {
      calls.add('disconnect ${args[0]}');
      return [null];
    });
    for (final method in ['connect', 'write', 'disconnect']) {
      answer(method, (args) {
        calls.add('ble $method ${args[0]}');
        if (method == 'connect') numbers.add(args[0]! as int);
        return [null];
      }, on: ble);
    }
    messenger.setMockStreamHandler(
      const EventChannel(
        'dev.flutter.pigeon.pitwall.BluetoothEvents.adapterEvents',
        pigeonMethodCodec,
      ),
      MockStreamHandler.inline(
        onListen: (_, sink) => events.stream.listen(sink.success),
      ),
    );
  });

  tearDown(() async {
    for (final method in ['connect', 'write', 'disconnect']) {
      messenger.setMockMessageHandler('$api.$method', null);
      messenger.setMockMessageHandler('$ble.$method', null);
    }
    await events.close();
  });

  test('closing an old connection leaves the newer one alone', () async {
    final gateway = AndroidBluetoothGateway();
    final old = gateway.connect('AA', AdapterType.classic);
    final oldTransport = await old.opened;
    final current = await gateway.connect('AA', AdapterType.classic).opened;
    final [first, second] = numbers;
    calls.clear();

    await old.close();
    await oldTransport.write([0x41]);
    await current.write([0x42]);

    expect(second, greaterThan(first));
    expect(calls, ['disconnect $first', 'write $first', 'write $second']);
  });

  test('a connection can be closed while Android is connecting', () async {
    connecting = Completer<void>();
    final connection = AndroidBluetoothGateway().connect(
      'AA',
      AdapterType.classic,
    );
    await Future<void>.delayed(Duration.zero);

    await connection.close();

    // Before Android answered: the number was Dart's from the start.
    expect(calls, [
      'connect ${numbers.single}',
      'disconnect ${numbers.single}',
    ]);
    connecting!.complete();
    await expectLater(connection.opened, throwsA(isA<PlatformException>()));
  });

  test(
    'closed without being awaited, a failed connect is nobody\'s error',
    () async {
      connecting = Completer<void>();
      final connection = AndroidBluetoothGateway().connect(
        'AA',
        AdapterType.classic,
      );
      await Future<void>.delayed(Duration.zero);

      await connection.close();
      connecting!.complete();
      // An unhandled error here would fail the test.
      await Future<void>.delayed(Duration.zero);
    },
  );

  test(
    'each connection hears only its own bytes, and ends when it drops',
    () async {
      final gateway = AndroidBluetoothGateway();
      final old = await gateway.connect('AA', AdapterType.classic).opened;
      final current = await gateway.connect('AA', AdapterType.classic).opened;
      final [first, second] = numbers;
      final heardOld = <List<int>>[];
      final heardCurrent = <List<int>>[];
      var oldEnded = false;
      old.input.listen(heardOld.add, onDone: () => oldEnded = true);
      current.input.listen(heardCurrent.add);
      await Future<void>.delayed(Duration.zero);

      events
        ..add(AdapterBytes(connection: first, bytes: Uint8List.fromList([1])))
        ..add(AdapterBytes(connection: second, bytes: Uint8List.fromList([2])))
        ..add(AdapterDropped(connection: first));
      await Future<void>.delayed(Duration.zero);

      expect(heardOld, [
        [1],
      ]);
      expect(heardCurrent, [
        [2],
      ]);
      expect(oldEnded, isTrue);
    },
  );

  test('a failed write says the connection is gone', () async {
    final transport = await AndroidBluetoothGateway()
        .connect('AA', AdapterType.classic)
        .opened;
    writesFail = true;

    await expectLater(transport.write([0x41]), throwsA(isA<TransportClosed>()));
  });

  test(
    'a Bluetooth LE adapter goes through its own calls, and the same events',
    () async {
      final gateway = AndroidBluetoothGateway();
      final connection = gateway.connect('AA:BB', AdapterType.ble);
      final transport = await connection.opened;
      final number = numbers.single;
      final heard = <List<int>>[];
      transport.input.listen(heard.add);
      await Future<void>.delayed(Duration.zero);

      await transport.write([0x41]);
      events.add(
        AdapterBytes(connection: number, bytes: Uint8List.fromList([7])),
      );
      await Future<void>.delayed(Duration.zero);
      await connection.close();

      expect(calls, [
        'ble connect $number',
        'ble write $number',
        'ble disconnect $number',
      ]);
      expect(heard, [
        [7],
      ]);
    },
  );

  test('classic and Bluetooth LE connections never share a number', () async {
    final gateway = AndroidBluetoothGateway();
    await gateway.connect('AA', AdapterType.classic).opened;
    await gateway.connect('BB', AdapterType.ble).opened;

    final [classic, bluetoothLe] = numbers;
    expect(bluetoothLe, greaterThan(classic));
  });
}
