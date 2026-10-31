import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/obd/elm327.dart';
import 'package:pitwall/obd/pids.dart';

import 'fake_transport.dart';

void main() {
  test('initialize resets and configures the adapter', () async {
    final transport = FakeTransport({
      // Echo is still on until ATE0 takes effect.
      'ATZ': 'ATZ\r\r\x00ELM327 v1.5',
      'ATE0': 'ATE0\rOK',
      'ATL0': 'OK',
      'ATS0': 'OK',
      'ATH0': 'OK',
      'ATSP0': 'OK',
    });
    final elm = Elm327(transport);

    expect(await elm.initialize(), 'ELM327 v1.5');
    expect(transport.sent, ['ATZ', 'ATE0', 'ATL0', 'ATS0', 'ATH0', 'ATSP0']);
  });

  test('reads a value with spaces and a SEARCHING line', () async {
    final elm = Elm327(FakeTransport({'012F': 'SEARCHING...\r41 2F 76'}));

    final fuel = await elm.read(standardPidsById[0x2F]!);

    expect(fuel, closeTo(46.27, 0.01));
  });

  test('reads a value without spaces', () async {
    final elm = Elm327(FakeTransport({'010C': '410C1AF8'}));

    expect(await elm.requestPid(0x0C), [0x1A, 0xF8]);
  });

  test('handles a reply split across chunks', () async {
    final elm = Elm327(FakeTransport({'010C': '410C1AF8'}, chunkSize: 3));

    expect(await elm.requestPid(0x0C), [0x1A, 0xF8]);
  });

  test('NO DATA means the value is missing', () async {
    final elm = Elm327(FakeTransport({'01A6': 'NO DATA'}));

    expect(await elm.read(standardPidsById[0xA6]!), isNull);
  });

  test('UNABLE TO CONNECT is an error', () async {
    final elm = Elm327(
      FakeTransport({'0100': 'SEARCHING...\rUNABLE TO CONNECT'}),
    );

    await expectLater(
      elm.supportedPids(),
      throwsA(
        isA<ElmException>().having(
          (e) => e.error,
          'error',
          ElmError.unableToConnect,
        ),
      ),
    );
  });

  test('an unknown command is an error', () async {
    final elm = Elm327(FakeTransport({'ATXX': '?'}));

    await expectLater(
      elm.send('ATXX'),
      throwsA(
        isA<ElmException>().having(
          (e) => e.error,
          'error',
          ElmError.unknownCommand,
        ),
      ),
    );
  });

  test('a missing prompt times out', () async {
    final elm = Elm327(FakeTransport({}));

    await expectLater(
      elm.send('0100', timeout: const Duration(milliseconds: 50)),
      throwsA(
        isA<ElmException>().having((e) => e.error, 'error', ElmError.timeout),
      ),
    );
  });

  test('supported PIDs follow the chain of ranges', () async {
    final transport = FakeTransport({
      '0100': '4100BE3EB811',
      '0120': '412080000000',
    });
    final elm = Elm327(transport);

    final supported = await elm.supportedPids();

    expect(supported, containsAll([0x05, 0x0C, 0x0D, 0x20, 0x21]));
    expect(supported, isNot(contains(0x02)));
    expect(transport.sent, ['0100', '0120']);
  });

  test('supported PIDs combine replies from several ECUs', () async {
    final elm = Elm327(
      FakeTransport({'0100': '410080000000\r410000000001', '0120': 'NO DATA'}),
    );

    expect(await elm.supportedPids(), {0x01, 0x20});
  });

  test(
    'a dropped connection fails the pending command and later ones',
    () async {
      final transport = FakeTransport({});
      final logged = <String>[];
      final elm = Elm327(
        transport,
        log: (command, raw) => logged.add('$command|$raw'),
      );
      final isDisconnected = throwsA(
        isA<ElmException>().having(
          (e) => e.error,
          'error',
          ElmError.disconnected,
        ),
      );

      final pending = elm.send('0100');
      await Future<void>.delayed(Duration.zero);
      await transport.disconnect();

      await expectLater(pending, isDisconnected);
      expect(elm.isClosed, isTrue);
      expect(logged, ['0100|(disconnected)']);
      await expectLater(elm.send('ATRV'), isDisconnected);
    },
  );

  test('log receives each command and raw reply', () async {
    final logged = <String>[];
    final elm = Elm327(
      FakeTransport({'010D': 'SEARCHING...\r410D34'}),
      log: (command, raw) => logged.add('$command|$raw'),
    );

    await elm.requestPid(0x0D);

    expect(logged, ['010D|SEARCHING...\r410D34\r\r']);
  });

  test('setTarget only sends what changed', () async {
    final transport = FakeTransport({
      'ATSH7C6': 'OK',
      'ATFCSH7C6': 'OK',
      'ATFCSD300000': 'OK',
      'ATFCSM1': 'OK',
      'ATCRA7CE': 'OK',
      'ATSH7DF': 'OK',
      'ATFCSM0': 'OK',
      'ATCRA': 'OK',
    });
    final elm = Elm327(transport);

    await elm.setTarget('7C6', receive: '7CE');
    await elm.setTarget('7C6', receive: '7CE');
    await elm.setTarget(null);

    expect(transport.sent, [
      'ATSH7C6',
      // Flow control goes to the module, so long replies arrive in full.
      'ATFCSH7C6',
      'ATFCSD300000',
      'ATFCSM1',
      'ATCRA7CE',
      'ATSH7DF',
      'ATFCSM0',
      'ATCRA',
    ]);
  });

  test('adapters without flow-control commands still work', () async {
    final transport = FakeTransport({
      'ATSH7C6': 'OK',
      'ATFCSH7C6': '?',
      'ATCRA7CE': 'OK',
      'ATSH7E0': 'OK',
    });
    final elm = Elm327(transport);

    await elm.setTarget('7C6', receive: '7CE');
    await elm.setTarget('7E0', receive: '7CE');

    expect(transport.sent, ['ATSH7C6', 'ATFCSH7C6', 'ATCRA7CE', 'ATSH7E0']);
  });

  test('a multi-frame reply with missing frames is dropped', () async {
    // Recorded: the module announced 15 bytes, only the first frame came.
    final elm = Elm327(FakeTransport({'22B002': '00F\r0:62B002E00000'}));

    expect(await elm.request(0x22, [0xB0, 0x02]), isEmpty);
  });

  test('setTarget rejects anything but a CAN id', () async {
    final elm = Elm327(FakeTransport({}));

    expect(() => elm.setTarget('7E0 ATZ'), throwsArgumentError);
  });

  test('request joins a multi-frame reply', () async {
    final elm = Elm327(
      FakeTransport({'22B002': '00A\r0:62B002010203\r1:04050607AAAAAA'}),
    );

    expect(await elm.request(0x22, [0xB0, 0x02]), [
      [1, 2, 3, 4, 5, 6, 7],
    ]);
  });

  test('battery voltage comes from ATRV', () async {
    final elm = Elm327(FakeTransport({'ATRV': '12.6V'}));

    expect(await elm.readBatteryVoltage(), 12.6);
  });

  test('concurrent commands are sent one at a time', () async {
    final elm = Elm327(FakeTransport({'010C': '410C1AF8', '010D': '410D34'}));

    final results = await Future.wait([
      elm.requestPid(0x0C),
      elm.requestPid(0x0D),
    ]);

    expect(results, [
      [0x1A, 0xF8],
      [0x34],
    ]);
  });
}
