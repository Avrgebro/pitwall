import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/settings/settings.dart';
import 'package:pitwall/core/vehicles/vehicle.dart';
import 'package:pitwall/state/focus_state.dart';
import 'package:pitwall/state/session_state.dart';

import '../helpers/fakes.dart';

final _tucson = Vehicle(
  id: 'tucson',
  name: 'Tucson',
  lastSeen: DateTime(2026, 11, 1, 9),
);
final _mazda = Vehicle(
  id: 'mazda',
  name: 'Mazda',
  lastSeen: DateTime(2026, 10, 30),
);
final _settings = AppSettings(vehicles: [_tucson, _mazda]);

void main() {
  test('Home shows the most recent car unless one is picked', () {
    expect(focusedVehicleFor(settings: _settings), _tucson);
    expect(focusedVehicleFor(settings: _settings, pickedId: 'mazda'), _mazda);
  });

  test('a car in a live session wins over a pick', () {
    expect(
      focusedVehicleFor(
        settings: _settings,
        liveId: 'tucson',
        pickedId: 'mazda',
      ),
      _tucson,
    );
  });

  test('a pick of a removed vehicle falls back to the most recent', () {
    expect(focusedVehicleFor(settings: _settings, pickedId: 'gone'), _tucson);
  });

  test('a car connecting clears the pick', () async {
    final container = ProviderContainer(
      overrides: testOverrides(settings: _settings),
    );
    addTearDown(container.dispose);
    container.listen(focusPickProvider, (_, _) {});

    container.read(focusPickProvider.notifier).pick('mazda');
    expect(container.read(focusPickProvider), 'mazda');

    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    container.read(sessionProvider.notifier).state = const SessionConnecting(
      'tucson',
    );
    expect(container.read(focusPickProvider), isNull);
  });
}
