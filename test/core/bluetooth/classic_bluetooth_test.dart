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
  late StreamController<AdapterEvent> events;
  var nextConnection = 0;
  var writesFail = false;

  void answer(String method, Object? Function(List<Object?> args) reply) =>
      messenger.setMockMessageHandler('$api.$method', (data) async {
        final args = codec.decodeMessage(data)! as List<Object?>;
        return codec.encodeMessage(reply(args));
      });

  setUp(() {
    calls = [];
    nextConnection = 0;
    writesFail = false;
    events = StreamController<AdapterEvent>.broadcast();
    answer('connect', (_) => [++nextConnection]);
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
    final old = await gateway.connect('AA');
    final current = await gateway.connect('AA');

    await old.close();
    await old.write([0x41]);
    await current.write([0x42]);

    expect(calls, ['disconnect 1', 'write 1', 'write 2']);
  });

  test(
    'each connection hears only its own bytes, and ends when it drops',
    () async {
      final gateway = ClassicBluetoothGateway();
      final old = await gateway.connect('AA');
      final current = await gateway.connect('AA');
      final heardOld = <List<int>>[];
      final heardCurrent = <List<int>>[];
      var oldEnded = false;
      old.input.listen(heardOld.add, onDone: () => oldEnded = true);
      current.input.listen(heardCurrent.add);
      await Future<void>.delayed(Duration.zero);

      events
        ..add(AdapterBytes(connection: 1, bytes: Uint8List.fromList([1])))
        ..add(AdapterBytes(connection: 2, bytes: Uint8List.fromList([2])))
        ..add(AdapterDropped(connection: 1));
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
    final transport = await ClassicBluetoothGateway().connect('AA');
    writesFail = true;

    await expectLater(transport.write([0x41]), throwsA(isA<TransportClosed>()));
  });
}
