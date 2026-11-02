import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/settings/settings.dart';
import 'package:pitwall/core/vehicles/vehicle.dart';
import 'package:pitwall/state/settings_state.dart';

import '../helpers/fakes.dart';

void main() {
  test('a head unit can belong to only one vehicle', () async {
    final container = ProviderContainer(
      overrides: testOverrides(
        settings: const AppSettings(
          vehicles: [
            Vehicle(
              id: 'tucson',
              name: 'Tucson',
              headUnitAddress: 'AA:BB:CC:DD:EE:FF',
              headUnitName: 'TUCSON BT',
            ),
            Vehicle(id: 'mazda', name: 'Mazda'),
          ],
        ),
      ),
    );
    addTearDown(container.dispose);
    await container.read(appSettingsProvider.future);
    final notifier = container.read(appSettingsProvider.notifier);

    await expectLater(
      notifier.setHeadUnit(
        'mazda',
        address: 'aa:bb:cc:dd:ee:ff',
        name: 'TUCSON BT',
      ),
      throwsStateError,
    );

    // Choosing it again for its own vehicle is fine.
    await notifier.setHeadUnit(
      'tucson',
      address: 'AA:BB:CC:DD:EE:FF',
      name: 'TUCSON BT',
    );
    expect(
      container
          .read(appSettingsProvider)
          .value!
          .vehicleById('mazda')!
          .headUnitAddress,
      isNull,
    );
  });
}
