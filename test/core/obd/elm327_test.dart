import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/obd/can_id.dart';
import 'package:pitwall/core/obd/elm327.dart';
import 'package:pitwall/core/obd/pids.dart';

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
      'ATFCSH7E0': 'OK',
      'ATFCSD300000': 'OK',
      'ATFCSM1': 'OK',
      'ATFCSM0': 'OK',
    });
    final elm = Elm327(transport);

    expect(await elm.initialize(), 'ELM327 v1.5');
    expect(transport.sent, [
      'ATZ',
      'ATE0',
      'ATL0',
      'ATS0',
      'ATH0',
      'ATSP0',
      'ATFCSH7E0',
      'ATFCSD300000',
      // Manual mode is the one setTarget relies on, so it's tried too.
      'ATFCSM1',
      'ATFCSM0',
    ]);
    expect(elm.setsFlowControl, isTrue);
  });

  test('an adapter that refuses manual flow control can\'t set it', () async {
    final elm = Elm327(
      FakeTransport({
        'ATZ': 'ELM327 v2.1',
        'ATE0': 'OK',
        'ATL0': 'OK',
        'ATS0': 'OK',
        'ATH0': 'OK',
        'ATSP0': 'OK',
        'ATFCSH7E0': 'OK',
        'ATFCSD300000': 'OK',
        'ATFCSM1': '?',
      }),
    );

    await elm.initialize();

    expect(elm.setsFlowControl, isFalse);
  });

  test('initialize finds out an adapter can\'t set flow control', () async {
    final elm = Elm327(
      FakeTransport({
        'ATZ': 'ELM327 v2.1',
        'ATE0': 'OK',
        'ATL0': 'OK',
        'ATS0': 'OK',
        'ATH0': 'OK',
        'ATSP0': 'OK',
        'ATFCSH7E0': 'OK',
        'ATFCSD300000': '?',
      }),
    );

    await elm.initialize();

    expect(elm.setsFlowControl, isFalse);
  });

  test('a flow-control probe left unanswered means it can\'t', () async {
    final elm = Elm327(
      FakeTransport({
        'ATZ': 'ELM327 v2.1',
        'ATE0': 'OK',
        'ATL0': 'OK',
        'ATS0': 'OK',
        'ATH0': 'OK',
        'ATSP0': 'OK',
        // ATFCSH7E0 gets no answer at all, and times out.
      }),
    );

    // Connecting still works.
    expect(await elm.initialize(), 'ELM327 v2.1');
    expect(elm.setsFlowControl, isFalse);
  });

  test('a probe answered late leaves the next command its own reply', () async {
    final transport = FakeTransport(
      {
        'ATZ': 'ELM327 v2.1',
        'ATE0': 'OK',
        'ATL0': 'OK',
        'ATS0': 'OK',
        'ATH0': 'OK',
        'ATSP0': 'OK',
        'ATFCSH7E0': '?',
        '0100': '4100BE3EB810',
      },
      delays: {'ATFCSH7E0': const Duration(milliseconds: 3200)},
    );
    final elm = Elm327(transport);

    await elm.initialize();

    expect(elm.setsFlowControl, isFalse);
    // The late `?` isn't taken for the car's answer.
    expect(await elm.supportedPids(), contains(0x0C));
  });

  test('reads a value with spaces and a SEARCHING line', () async {
    final elm = Elm327(FakeTransport({'012F': 'SEARCHING...\r41 2F 76'}));

    final data = await elm.requestPid(0x2F);

    expect(standardPidsById[0x2F]!.tryDecode(data!), closeTo(46.27, 0.01));
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

    expect(await elm.requestPid(0xA6), isNull);
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

  test('a reply that comes late goes to its own command', () async {
    final transport = FakeTransport(
      {'0902': '4902014B4D48', 'ATRV': '12.4V'},
      delays: {'0902': const Duration(milliseconds: 100)},
    );
    final logged = <String>[];
    final elm = Elm327(
      transport,
      log: (command, raw, error) => logged.add('$command|$raw|${error?.name}'),
    );

    await expectLater(
      elm.send('0902', timeout: const Duration(milliseconds: 50)),
      throwsA(
        isA<ElmException>().having((e) => e.error, 'error', ElmError.timeout),
      ),
    );

    expect(await elm.readBatteryVoltage(), 12.4);
    expect(logged, [
      '0902|(timeout)|timeout',
      '0902|(late) 4902014B4D48\r\r|null',
      'ATRV|12.4V\r\r|null',
    ]);
  });

  test('a reply that never comes keeps later commands unsent', () async {
    final transport = FakeTransport({'ATRV': '12.4V'});
    final elm = Elm327(transport);
    final timesOut = throwsA(
      isA<ElmException>().having((e) => e.error, 'error', ElmError.timeout),
    );
    const short = Duration(milliseconds: 50);

    await expectLater(elm.send('0100', timeout: short), timesOut);
    await expectLater(elm.send('ATRV', timeout: short), timesOut);

    // Written, the command's reply would be mistaken for the one owed.
    expect(transport.sent, ['0100']);
  });

  test('a drop while a reply is owed fails the next command', () async {
    final transport = FakeTransport({});
    final elm = Elm327(transport);
    const short = Duration(milliseconds: 50);
    await expectLater(elm.send('0100', timeout: short), throwsA(anything));

    final next = elm.send('ATRV');
    await Future<void>.delayed(Duration.zero);
    await transport.disconnect();

    await expectLater(
      next,
      throwsA(
        isA<ElmException>().having(
          (e) => e.error,
          'error',
          ElmError.disconnected,
        ),
      ),
    );
  });

  test('only commands that read are ever sent', () async {
    final transport = FakeTransport({'0902': '490201'});
    final elm = Elm327(transport);

    for (final command in ['04', '14FFFFFF', '2EF19001', '1101', '3101FF00']) {
      await expectLater(
        elm.send(command),
        throwsA(
          isA<ElmException>().having(
            (e) => e.error,
            'error',
            ElmError.changesCar,
          ),
        ),
        reason: command,
      );
    }
    await elm.send('0902');

    expect(transport.sent, ['0902']);
    for (final command in ['ATZ', 'STDI', '010C', '03', '0A', '22F190']) {
      expect(Elm327.onlyReads(command), isTrue, reason: command);
    }
    expect(Elm327.onlyReads('HELLO'), isFalse);
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
        log: (command, raw, error) =>
            logged.add('$command|$raw|${error?.name}'),
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
      expect(logged, ['0100|(disconnected)|disconnected']);
      await expectLater(elm.send('ATRV'), isDisconnected);
    },
  );

  test('a drop is heard at once, with no command waiting', () async {
    final transport = FakeTransport({});
    final elm = Elm327(transport);
    var closed = false;
    unawaited(elm.closed.then((_) => closed = true));

    await transport.disconnect();
    await Future<void>.delayed(Duration.zero);

    expect(closed, isTrue);
  });

  test('log receives each command, raw reply and what it means', () async {
    final logged = <String>[];
    final elm = Elm327(
      FakeTransport({'010D': 'SEARCHING...\r410D34', '010C': 'NO DATA'}),
      log: (command, raw, error) => logged.add('$command|$raw|${error?.name}'),
    );

    await elm.requestPid(0x0D);
    await elm.requestPid(0x0C);

    expect(logged, [
      '010D|SEARCHING...\r410D34\r\r|null',
      '010C|NO DATA\r\r|noData',
    ]);
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

    await elm.setTarget(_id('7C6'), receive: _id('7CE'));
    await elm.setTarget(_id('7C6'), receive: _id('7CE'));
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

  test('an adapter found without flow control is never asked for it', () async {
    final transport = FakeTransport({
      'ATZ': 'ELM327 v2.1',
      'ATE0': 'OK',
      'ATL0': 'OK',
      'ATS0': 'OK',
      'ATH0': 'OK',
      'ATSP0': 'OK',
      'ATFCSH7E0': '?',
      'ATSH7C6': 'OK',
      'ATCRA7CE': 'OK',
      'ATSH7E0': 'OK',
    });
    final elm = Elm327(transport);
    await elm.initialize();
    transport.sent.clear();

    await elm.setTarget(_id('7C6'), receive: _id('7CE'));
    await elm.setTarget(_id('7E0'), receive: _id('7CE'));

    expect(transport.sent, ['ATSH7C6', 'ATCRA7CE', 'ATSH7E0']);
  });

  test('a multi-frame reply with missing frames is dropped', () async {
    // Recorded: the module announced 15 bytes, only the first frame came.
    final elm = Elm327(FakeTransport({'22B002': '00F\r0:62B002E00000'}));

    expect(await elm.request(0x22, [0xB0, 0x02]), isEmpty);
  });

  test('only an 11-bit id is a CAN id', () {
    expect(CanId.tryParse('7e0'), '7E0');
    expect(CanId.tryParse('7E0 ATZ'), isNull);
    expect(CanId.tryParse('18DA10F1'), isNull);
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

CanId _id(String hex) => CanId.tryParse(hex)!;
