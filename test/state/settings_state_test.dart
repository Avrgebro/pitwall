import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/profiles/profile_ref.dart';
import 'package:pitwall/core/bluetooth/adapter_type.dart';
import 'package:pitwall/core/bluetooth/bluetooth_gateway.dart';
import 'package:pitwall/core/platform/file_gateway.dart';
import 'package:pitwall/core/settings/settings.dart';
import 'package:pitwall/core/readings/last_values.dart';
import 'package:pitwall/core/profiles/stored_profile.dart';
import 'package:pitwall/core/vehicles/vehicle.dart';
import 'package:pitwall/state/last_values_state.dart';
import 'package:pitwall/state/settings_state.dart';

import '../core/profiles/test_profile.dart';
import '../core/settings/fake_settings_store.dart';
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
              headUnit: HeadUnit(
                address: 'AA:BB:CC:DD:EE:FF',
                name: 'TUCSON BT',
              ),
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
          .headUnit
          ?.address,
      isNull,
    );
  });

  group('adapters', () {
    const vlinker = BondedDevice(
      name: 'vLinker MC+',
      address: '00:1D:A5:68:98:8B',
      type: AdapterType.classic,
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
      expect(saved.adapter?.address, vlinker.address);
      expect(saved.adapter?.name, vlinker.name);
      expect(saved.adapter?.type, AdapterType.classic);
    });

    test('the adapter keeps how it connects', () async {
      final container = await start(const AppSettings());

      await container
          .read(appSettingsProvider.notifier)
          .addVehicle(
            name: 'Tucson',
            adapter: const BondedDevice(
              name: 'iCar Pro',
              address: 'C0:FF:EE:00:00:01',
              type: AdapterType.ble,
            ),
          );

      expect(
        container
            .read(appSettingsProvider)
            .value!
            .vehicles
            .single
            .adapter
            ?.type,
        AdapterType.ble,
      );
    });

    test('changing the adapter keeps the rest of the vehicle', () async {
      final container = await start(
        const AppSettings(
          vehicles: [
            Vehicle(
              id: 'tucson',
              name: 'Tucson',
              adapter: VehicleAdapter(
                address: 'AA',
                name: 'Old',
                type: AdapterType.classic,
              ),

              headUnit: HeadUnit(address: 'BB', name: 'BB'),
            ),
          ],
        ),
      );

      await container
          .read(appSettingsProvider.notifier)
          .setAdapter('tucson', vlinker);

      final saved = container.read(appSettingsProvider).value!.vehicles.single;
      expect(saved.adapter?.address, vlinker.address);
      expect(saved.adapter?.name, vlinker.name);
      expect(saved.name, 'Tucson');
      expect(saved.headUnit?.address, 'BB');
    });
  });

  group('profiles', () {
    Future<(ProviderContainer, FakeSettingsStore)> start({
      ProfileRef? profile,
    }) async {
      final store = FakeSettingsStore(
        settings: AppSettings(
          vehicles: [
            Vehicle(
              id: 'tucson',
              name: 'Tucson',
              modelYear: 2023,
              profile: profile,
            ),
          ],
        ),
      );
      final container = ProviderContainer(
        overrides: testOverrides(store: store),
      );
      addTearDown(container.dispose);
      await container.read(appSettingsProvider.future);
      return (container, store);
    }

    test('importing saves the file and the vehicle together', () async {
      final (container, store) = await start();

      await container
          .read(appSettingsProvider.notifier)
          .importProfile(
            'tucson',
            const PickedFile(name: 'default.json', contents: testProfileJson),
          );

      expect(store.profiles['tucson'], testProfileJson);
      final vehicle = container.read(vehicleProvider('tucson'))!;
      expect(vehicle.profile?.name, 'default.json');
      expect(vehicle.profile?.importedAt, isNotNull);
      expect(
        await container.read(vehicleProfileProvider('tucson').future),
        isNotNull,
      );
    });

    test('a file that isn\'t a profile is refused before saving', () async {
      final (container, store) = await start();

      await expectLater(
        container
            .read(appSettingsProvider.notifier)
            .importProfile(
              'tucson',
              const PickedFile(name: 'notes.json', contents: '{}'),
            ),
        throwsFormatException,
      );
      expect(store.profiles, isEmpty);
      expect(container.read(vehicleProvider('tucson'))!.profile, isNull);
    });

    test('a profile whose file is gone is reported, not hidden', () async {
      final (container, _) = await start(
        profile: const ProfileRef('default.json'),
      );

      expect(
        await container.read(vehicleProfileProvider('tucson').future),
        isA<UnreadableProfile>().having(
          (p) => p.ref.name,
          'file',
          'default.json',
        ),
      );
    });

    test('removing clears the file, the profile and its model year', () async {
      final (container, store) = await start(
        profile: const ProfileRef('default.json'),
      );
      store.profiles['tucson'] = testProfileJson;

      await container
          .read(appSettingsProvider.notifier)
          .removeProfile('tucson');

      expect(store.profiles, isEmpty);
      final vehicle = container.read(vehicleProvider('tucson'))!;
      expect(vehicle.profile, isNull);
      // It only chose which of the profile's requests apply.
      expect(vehicle.modelYear, isNull);
    });

    test('a removed profile can be put back', () async {
      final (container, store) = await start(
        profile: const ProfileRef('default.json'),
      );
      store.profiles['tucson'] = testProfileJson;
      final notifier = container.read(appSettingsProvider.notifier);
      final profile = await container.read(
        vehicleProfileProvider('tucson').future,
      ) as LoadedProfile;

      await notifier.removeProfile('tucson');
      await notifier.restoreProfile('tucson', profile, modelYear: 2023);

      expect(store.profiles['tucson'], testProfileJson);
      final vehicle = container.read(vehicleProvider('tucson'))!;
      expect(vehicle.profile?.name, 'default.json');
      expect(vehicle.modelYear, 2023);
    });

    test('a rename while the profile is written is kept', () async {
      final (container, store) = await start();
      final notifier = container.read(appSettingsProvider.notifier);
      final write = Completer<void>();
      store.profileWrite = write.future;

      final importing = notifier.importProfile(
        'tucson',
        const PickedFile(name: 'default.json', contents: testProfileJson),
      );
      await Future<void>.delayed(Duration.zero);
      await notifier.renameVehicle('tucson', 'Hyundai Tucson');
      write.complete();
      await importing;

      final vehicle = store.settings.vehicleById('tucson')!;
      expect(vehicle.name, 'Hyundai Tucson');
      expect(vehicle.profile?.name, 'default.json');
    });

    test('a vehicle deleted while its profile is written stays gone', () async {
      final (container, store) = await start();
      final notifier = container.read(appSettingsProvider.notifier);
      final write = Completer<void>();
      store.profileWrite = write.future;

      final importing = notifier.importProfile(
        'tucson',
        const PickedFile(name: 'default.json', contents: testProfileJson),
      );
      await Future<void>.delayed(Duration.zero);
      await notifier.deleteVehicle('tucson');
      write.complete();
      await importing;

      expect(store.settings.vehicles, isEmpty);
      expect(store.profiles, isEmpty);
    });

    test('Undo doesn\'t replace a profile imported since', () async {
      final (container, store) = await start(
        profile: const ProfileRef('default.json'),
      );
      store.profiles['tucson'] = testProfileJson;
      final notifier = container.read(appSettingsProvider.notifier);
      final profile = await container.read(
        vehicleProfileProvider('tucson').future,
      ) as LoadedProfile;

      await notifier.removeProfile('tucson');
      await notifier.importProfile(
        'tucson',
        const PickedFile(name: 'newer.json', contents: testProfileJson),
      );
      await notifier.restoreProfile('tucson', profile, modelYear: 2023);

      expect(
        container.read(vehicleProvider('tucson'))!.profile?.name,
        'newer.json',
      );
    });
  });

  test('a deleted vehicle\'s last values go with it', () async {
    final storage = FakeLastValuesStorage()
      ..saved = const LastValues()
          .record('tucson', {'rpm': 800}, DateTime(2026, 11, 2), seq: 1)
          .record('mazda', {'rpm': 900}, DateTime(2026, 11, 2), seq: 1);
    final container = ProviderContainer(
      overrides: testOverrides(
        settings: const AppSettings(
          vehicles: [
            Vehicle(id: 'tucson', name: 'Tucson'),
            Vehicle(id: 'mazda', name: 'Mazda'),
          ],
        ),
        lastValues: storage,
      ),
    );
    addTearDown(container.dispose);
    await container.read(appSettingsProvider.future);
    await container.read(lastValuesProvider.future);

    await container.read(appSettingsProvider.notifier).deleteVehicle('tucson');
    await Future<void>.delayed(Duration.zero);

    expect(storage.saved.of('tucson'), isEmpty);
    expect(storage.saved.of('mazda'), isNotEmpty);
  });

  test('a reading for a vehicle deleted meanwhile keeps no values', () async {
    final storage = FakeLastValuesStorage();
    final container = ProviderContainer(
      overrides: testOverrides(
        settings: const AppSettings(
          vehicles: [Vehicle(id: 'mazda', name: 'Mazda')],
        ),
        lastValues: storage,
      ),
    );
    addTearDown(container.dispose);

    await container
        .read(lastValuesProvider.notifier)
        .record('tucson', {'rpm': 800}, DateTime(2026, 11, 2), seq: 3);

    expect(storage.saved.of('tucson'), isEmpty);
  });

  test('settings land on disk in the order they were made', () async {
    final store = FakeSettingsStore(
      settings: const AppSettings(
        vehicles: [Vehicle(id: 'tucson', name: 'A')],
      ),
    );
    final container = ProviderContainer(overrides: testOverrides(store: store));
    addTearDown(container.dispose);
    await container.read(appSettingsProvider.future);
    final notifier = container.read(appSettingsProvider.notifier);
    // The first write is slow; the second must not land before it.
    final slow = Completer<void>();
    store.nextSave = slow.future;

    final first = notifier.renameVehicle('tucson', 'B');
    final second = notifier.renameVehicle('tucson', 'C');
    slow.complete();
    await (first, second).wait;

    expect(store.settings.vehicleById('tucson')!.name, 'C');
  });
}
