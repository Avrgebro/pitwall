import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/bluetooth/bluetooth_gateway.dart';
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

  group('adapters', () {
    const vlinker = BondedDevice(
      name: 'vLinker MC+',
      address: '00:1D:A5:68:98:8B',
    );

    Future<ProviderContainer> start(AppSettings settings) async {
      final container = ProviderContainer(
        overrides: testOverrides(settings: settings),
      );
      addTearDown(container.dispose);
      await container.read(appSettingsProvider.future);
      return container;
    }

    test('adding a vehicle saves its name and adapter', () async {
      final container = await start(const AppSettings());

      final added = await container
          .read(appSettingsProvider.notifier)
          .addVehicle(name: ' Tucson ', adapter: vlinker);

      final saved = container.read(appSettingsProvider).value!.vehicles.single;
      expect(saved.id, added.id);
      expect(saved.name, 'Tucson');
      expect(saved.adapterAddress, vlinker.address);
      expect(saved.adapterName, vlinker.name);
      expect(saved.adapterType, AdapterType.classic);
    });

    test('changing the adapter keeps the rest of the vehicle', () async {
      final container = await start(
        const AppSettings(
          vehicles: [
            Vehicle(
              id: 'tucson',
              name: 'Tucson',
              adapterAddress: 'AA',
              adapterName: 'Old',
              headUnitAddress: 'BB',
            ),
          ],
        ),
      );

      await container
          .read(appSettingsProvider.notifier)
          .setAdapter('tucson', vlinker);

      final saved = container.read(appSettingsProvider).value!.vehicles.single;
      expect(saved.adapterAddress, vlinker.address);
      expect(saved.adapterName, vlinker.name);
      expect(saved.name, 'Tucson');
      expect(saved.headUnitAddress, 'BB');
    });
  });
}
