import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/bluetooth/classic_bluetooth.dart';
import 'package:pitwall/core/obd/obd_transport.dart';
import 'package:pitwall/core/platform/messages.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const api = 'dev.flutter.pigeon.pitwall.ClassicBluetoothApi';
  const codec = ClassicBluetoothApi.pigeonChannelCodec;

  late List<String> calls;
  late List<int> numbers;
  late StreamController<AdapterEvent> events;
  var writesFail = false;

  /// Holds Android's answer to connect until it completes.
  Completer<void>? connecting;

  void answer(
    String method,
    FutureOr<Object?> Function(List<Object?> args) reply,
  ) => messenger.setMockMessageHandler('$api.$method', (data) async {
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
      numbers.add(args[0]! as int);
      calls.add('connect ${args[0]}');
      await connecting?.future;
      return [null];
    });
    answer('write', (args) {
      calls.add('write ${args[0]}');
      return writesFail ? ['write_failed', 'Gone', null] : [null];
    });
    answer('disconnect', (args) {
      calls.add('disconnect ${args[0]}');
      return [null];
    });
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
    }
    await events.close();
  });

  test('closing an old connection leaves the newer one alone', () async {
    final gateway = ClassicBluetoothGateway();
    final old = gateway.connect('AA');
    final oldTransport = await old.opened;
    final current = await gateway.connect('AA').opened;
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
    final connection = ClassicBluetoothGateway().connect('AA');
    await Future<void>.delayed(Duration.zero);

    await connection.close();

    // Before Android answered: the number was Dart's from the start.
    expect(calls, [
      'connect ${numbers.single}',
      'disconnect ${numbers.single}',
    ]);
    connecting!.complete();
    await connection.opened;
  });

  test(
    'each connection hears only its own bytes, and ends when it drops',
    () async {
      final gateway = ClassicBluetoothGateway();
      final old = await gateway.connect('AA').opened;
      final current = await gateway.connect('AA').opened;
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
    final transport = await ClassicBluetoothGateway().connect('AA').opened;
    writesFail = true;

    await expectLater(transport.write([0x41]), throwsA(isA<TransportClosed>()));
  });
}
