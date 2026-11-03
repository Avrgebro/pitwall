import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/bluetooth/bluetooth_gateway.dart';
import 'package:pitwall/core/session/car_reading.dart';
import 'package:pitwall/core/settings/settings.dart';
import 'package:pitwall/core/vehicles/vehicle.dart';
import 'package:pitwall/state/infrastructure.dart';
import 'package:pitwall/state/session_state.dart';
import 'package:pitwall/state/settings_state.dart';

import '../core/obd/fake_transport.dart';
import '../helpers/fakes.dart';

/// An adapter on a car with the ignition on.
class _Adapter extends FakeTransport implements ClosableTransport {
  _Adapter()
    : super({
        'ATZ': 'ELM327 v2.1',
        'ATE0': 'OK',
        'ATL0': 'OK',
        'ATS0': 'OK',
        'ATH0': 'OK',
        'ATSP0': 'OK',
        '0100': '410000000000',
        'ATRV': '13.6V',
      });

  @override
  Future<void> close() async {}
}

const _tucson = Vehicle(
  id: 'tucson',
  name: 'Tucson',
  adapterAddress: '00:1D:A5:68:98:8B',
  adapterName: 'vLinker MC+',
);

void main() {
  late FakeBluetoothGateway bluetooth;
  late List<_Adapter> adapters;

  Future<ProviderContainer> start() async {
    adapters = [];
    bluetooth = FakeBluetoothGateway(
      adapter: (_) {
        final adapter = _Adapter();
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

  test('disconnecting during a read is a clean disconnect', () async {
    final c = await start();
    final session = c.read(sessionProvider.notifier);
    await session.connect(_tucson);
    // The battery voltage goes unanswered, so the read waits on it.
    adapters.single.replies.remove('ATRV');

    final reading = session.read();
    await Future<void>.delayed(Duration.zero);
    await session.disconnect();

    expect(await reading, isA<StepFailed<CarReading>>());
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
    expect(await session.read(), isA<StepDone<CarReading>>());
  });
}
