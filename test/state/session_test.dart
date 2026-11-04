import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/bluetooth/adapter_type.dart';
import 'package:pitwall/core/obd/obd_transport.dart';
import 'package:pitwall/core/session/car_state.dart';
import 'package:pitwall/core/settings/settings.dart';
import 'package:pitwall/core/vehicles/vehicle.dart';
import 'package:pitwall/state/infrastructure.dart';
import 'package:pitwall/state/session_state.dart';
import 'package:pitwall/state/settings_state.dart';

import '../core/obd/fake_transport.dart';
import '../helpers/fakes.dart';

/// An adapter on a car with the ignition on.
class _Adapter extends FakeTransport implements ClosableAdapter {
  _Adapter()
    : super({
        'ATZ': 'ELM327 v2.1',
        'ATE0': 'OK',
        'ATL0': 'OK',
        'ATS0': 'OK',
        'ATH0': 'OK',
        'ATSP0': 'OK',
        'ATFCSM0': 'OK',
        '0100': '410000000000',
        'ATRV': '13.6V',
      });

  bool closed = false;

  /// Makes writing fail, as when the adapter drops.
  bool writesFail = false;

  /// Holds closing until it completes.
  Future<void>? closing;

  @override
  Future<void> write(List<int> bytes) async {
    if (writesFail || closed) throw const TransportClosed();
    await super.write(bytes);
  }

  @override
  Future<void> close() async {
    closed = true;
    if (closing case final hold?) await hold;
  }
}

const _tucson = Vehicle(
  id: 'tucson',
  name: 'Tucson',
  adapter: VehicleAdapter(
    address: '00:1D:A5:68:98:8B',
    name: 'vLinker MC+',
    type: AdapterType.classic,
  ),
);

void main() {
  late FakeBluetoothGateway bluetooth;
  late List<_Adapter> adapters;

  /// Makes the adapters handed out next fail every write.
  var writesFail = false;

  /// Makes the adapters handed out next leave the reset unanswered, so a
  /// connection waits in it with its transport open.
  var answersReset = true;

  /// Replies the adapters handed out next give, over their usual ones.
  var answers = <String, String>{};

  Future<ProviderContainer> start() async {
    adapters = [];
    writesFail = false;
    answersReset = true;
    answers = {};
    bluetooth = FakeBluetoothGateway(
      adapter: (_) {
        final adapter = _Adapter()..writesFail = writesFail;
        if (!answersReset) adapter.replies.remove('ATZ');
        adapter.replies.addAll(answers);
        adapters.add(adapter);
        return adapter;
      },
    );
    final container = ProviderContainer(
      overrides: testOverrides(
        settings: const AppSettings(vehicles: [_tucson]),
        bluetooth: bluetooth,
      ),
    );
    addTearDown(container.dispose);
    await container.read(appSettingsProvider.future);
    return container;
  }

  test('a second connect while one is under way is refused', () async {
    final c = await start();
    final session = c.read(sessionProvider.notifier);

    final first = session.connect(_tucson);
    final second = await session.connect(_tucson);

    expect(second, isA<StepRefused<SessionConnected>>());
    expect(await first, isA<StepDone<SessionConnected>>());
    expect(bluetooth.connected, hasLength(1));
  });

  test('disconnecting while connecting abandons the connection', () async {
    final c = await start();
    final session = c.read(sessionProvider.notifier);

    final connecting = session.connect(_tucson);
    await session.disconnect();

    expect(await connecting, isA<StepFailed<SessionConnected>>());
    expect(c.read(sessionProvider), isA<SessionIdle>());
  });

  test(
    'disconnecting while the adapter connects closes that connect',
    () async {
      final c = await start();
      final session = c.read(sessionProvider.notifier);
      final slow = Completer<void>();
      bluetooth.opening = slow.future;

      final connecting = session.connect(_tucson);
      while (adapters.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      await session.disconnect();

      // Closed while still connecting, not once the connect is done.
      expect(adapters.single.closed, isTrue);
      slow.complete();
      expect(await connecting, isA<StepFailed<SessionConnected>>());
      expect(adapters.single.sent, isEmpty);
      expect(c.read(sessionProvider), isA<SessionIdle>());
    },
  );

  test('disconnecting once the transport is open closes it at once', () async {
    final c = await start();
    final session = c.read(sessionProvider.notifier);
    answersReset = false;

    final connecting = session.connect(_tucson);
    while (adapters.isEmpty || adapters.single.sent.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    await session.disconnect();

    // Not after the reset's timeout: closing fails what it waits for.
    expect(
      await connecting.timeout(const Duration(seconds: 1)),
      isA<StepFailed<SessionConnected>>(),
    );
    expect(adapters.single.closed, isTrue);
    expect(c.read(sessionProvider), isA<SessionIdle>());
  });

  test('disconnecting during a read is a clean disconnect', () async {
    final c = await start();
    final session = c.read(sessionProvider.notifier);
    await session.connect(_tucson);
    // The battery voltage goes unanswered, so the read waits on it.
    adapters.single.replies.remove('ATRV');

    final reading = session.read();
    await Future<void>.delayed(Duration.zero);
    await session.disconnect();

    expect(await reading, isA<StepFailed<VehicleReading>>());
    expect(c.read(sessionProvider), isA<SessionIdle>());
    expect((c.read(sessionProvider) as SessionIdle).problem, isNull);
    expect(
      c.read(adapterLogProvider).entries.value.map((e) => e.text),
      isNot(contains(startsWith('Adapter error'))),
    );
  });

  test('a read cut short by a disconnect leaves a new session alone', () async {
    final c = await start();
    final session = c.read(sessionProvider.notifier);
    await session.connect(_tucson);
    adapters.single.replies.remove('ATRV');

    final stale = session.read();
    await Future<void>.delayed(Duration.zero);
    await session.disconnect();
    await session.connect(_tucson);
    await stale;

    final live = c.read(sessionProvider);
    expect(live, isA<SessionConnected>());
    expect((live as SessionConnected).busy, isFalse);
    expect(await session.read(), isA<StepDone<VehicleReading>>());
  });

  test('once the car is off, it supports no values', () async {
    final c = await start();
    final session = c.read(sessionProvider.notifier);
    await session.connect(_tucson);
    // It answers with some values supported, and no further ranges.
    adapters.single.replies['0100'] = '4100BE3EB810';
    await session.checkCar();
    expect(
      (c.read(sessionProvider) as SessionConnected).supportedPids,
      isNotEmpty,
    );
    adapters.single.replies['0100'] = 'SEARCHING...\rUNABLE TO CONNECT';

    await session.checkCar();

    final live = c.read(sessionProvider) as SessionConnected;
    expect(live.carState, CarState.off);
    expect(live.supportedPids, isEmpty);
  });

  test('a reading says which vehicle it was for', () async {
    final c = await start();
    final session = c.read(sessionProvider.notifier);
    await session.connect(_tucson);

    final outcome = await session.read();

    expect(
      outcome,
      isA<StepDone<VehicleReading>>().having(
        (o) => o.value.vehicle.id,
        'vehicle',
        'tucson',
      ),
    );
  });

  test('the log says which chosen values didn\'t come, and why', () async {
    final c = await start();
    final session = c.read(sessionProvider.notifier);
    answers = {
      // Engine speed and vehicle speed, 0C and 0D, are supported.
      '0100': '410000180000',
      '010C': '410C1AF8',
      '010D': 'NO DATA',
    };
    await session.connect(_tucson);

    await session.read();

    final notes = c.read(adapterLogProvider).entries.value.map((e) => e.text);
    expect(notes, contains('speed_kmh not sent: its request got no answer'));
    expect(
      notes,
      contains('coolant_temp_c not sent: the car doesn\'t list it'),
    );
  });

  test('raw commands are split and sent as typed, in capitals', () async {
    final c = await start();
    final session = c.read(sessionProvider.notifier);
    await session.connect(_tucson);
    adapters.single.replies['ATI'] = 'ELM327 v2.1';
    adapters.single.replies['0100'] = '410000000000';

    final outcome = await session.sendRaw(' ati, 0100 ');

    expect(outcome, isA<StepDone<void>>());
    expect(adapters.single.sent, containsAllInOrder(['ATI', '0100']));
  });

  test('a connect abandoned midway leaves the next connection alone', () async {
    final c = await start();
    final session = c.read(sessionProvider.notifier);
    // The first adapter doesn't answer the reset, so that connect waits.
    final first = session.connect(_tucson);
    await Future<void>.delayed(Duration.zero);
    adapters.first.replies.remove('ATZ');
    await session.disconnect();
    final second = await session.connect(_tucson);
    await first;

    expect(second, isA<StepDone<SessionConnected>>());
    expect(adapters.first.closed, isTrue);
    expect(adapters.last.closed, isFalse);
    expect(c.read(sessionProvider), isA<SessionConnected>());
    expect(await session.read(), isA<StepDone<VehicleReading>>());
  });

  test('a write that fails while connecting leaves the session idle', () async {
    final c = await start();
    final session = c.read(sessionProvider.notifier);
    writesFail = true;
    final connecting = session.connect(_tucson);

    expect(await connecting, isA<StepFailed<SessionConnected>>());
    expect(
      c.read(sessionProvider),
      isA<SessionIdle>().having(
        (s) => s.problem,
        'problem',
        ConnectionProblem.disconnected,
      ),
    );
    // Not stuck: it connects again.
    writesFail = false;
    expect(await session.connect(_tucson), isA<StepDone<SessionConnected>>());
  });

  test('a write that fails while reading is a dropped adapter', () async {
    final c = await start();
    final session = c.read(sessionProvider.notifier);
    await session.connect(_tucson);
    adapters.single.writesFail = true;

    expect(
      await session.read(),
      isA<StepFailed<VehicleReading>>().having(
        (o) => o.problem,
        'problem',
        ConnectionProblem.disconnected,
      ),
    );
    expect(c.read(sessionProvider), isA<SessionIdle>());
    expect(adapters.single.closed, isTrue);
  });

  test('disconnecting is idle before the connection is closed', () async {
    final c = await start();
    final session = c.read(sessionProvider.notifier);
    await session.connect(_tucson);
    final hold = Completer<void>();
    adapters.single.closing = hold.future;

    final disconnecting = session.disconnect();

    expect(c.read(sessionProvider), isA<SessionIdle>());
    // Asking for the same vehicle now makes a new connection.
    expect(session.connect(_tucson), completes);
    hold.complete();
    await disconnecting;
  });
}
