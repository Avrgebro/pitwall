import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/bluetooth/adapter_type.dart';
import 'package:pitwall/core/bluetooth/bluetooth_gateway.dart';
import 'package:pitwall/core/platform/file_gateway.dart';
import 'package:pitwall/core/profiles/profile_ref.dart';
import 'package:pitwall/core/profiles/stored_profile.dart';
import 'package:pitwall/core/readings/last_values.dart';
import 'package:pitwall/core/settings/settings.dart';
import 'package:pitwall/core/vehicles/vehicle.dart';
import 'package:pitwall/core/webhook/webhook_target.dart';
import 'package:pitwall/state/last_values_state.dart';
import 'package:pitwall/state/settings_state.dart';
import 'package:pitwall/state/webhook_state.dart';

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

    test(
      'importing replaces the old file once the settings are saved',
      () async {
        final (container, store) = await start(
          profile: const ProfileRef('default.json'),
        );
        store.putProfile(
          'tucson',
          const ProfileRef('default.json'),
          testProfileJson,
        );

        await container
            .read(appSettingsProvider.notifier)
            .importProfile(
              'tucson',
              const PickedFile(name: 'newer.json', contents: testProfileJson),
            );

        expect(store.files, hasLength(1));
        expect(store.profileOf('tucson'), testProfileJson);
        expect(
          store.settings.vehicleById('tucson')!.profile?.name,
          'newer.json',
        );
      },
    );

    test(
      'an import whose settings can\'t be saved leaves the old one whole',
      () async {
        const older =
            '{"commands": [{"hdr": "7E0", "rax": "7E8", '
            '"cmd": {"22": "0001"}, "signals": [{"id": "OLD", '
            '"fmt": {"len": 8}}]}]}';
        final (container, store) = await start(
          profile: const ProfileRef('default.json'),
        );
        store
          ..putProfile('tucson', const ProfileRef('default.json'), older)
          ..saveError = const FileSystemException('disk full');

        await expectLater(
          container
              .read(appSettingsProvider.notifier)
              .importProfile(
                'tucson',
                const PickedFile(name: 'newer.json', contents: testProfileJson),
              ),
          throwsA(isA<FileSystemException>()),
        );

        // The old name still goes with the old signals, and nothing else is
        // left behind.
        final vehicle = container.read(vehicleProvider('tucson'))!;
        expect(vehicle.profile?.name, 'default.json');
        expect(store.profileOf('tucson'), older);
        expect(store.files, hasLength(1));
      },
    );

    test(
      'an import whose settings never land fails, with a change during it',
      () async {
        const older =
            '{"commands": [{"hdr": "7E0", "rax": "7E8", '
            '"cmd": {"22": "0001"}, "signals": [{"id": "OLD", '
            '"fmt": {"len": 8}}]}]}';
        final (container, store) = await start(
          profile: const ProfileRef('default.json'),
        );
        store.putProfile('tucson', const ProfileRef('default.json'), older);
        final notifier = container.read(appSettingsProvider.notifier);
        final failing = Completer<void>();
        store.nextSave = failing.future;

        final importing = notifier.importProfile(
          'tucson',
          const PickedFile(name: 'newer.json', contents: testProfileJson),
        );
        // The import's settings write is under way; a rename comes during it.
        while (store.saves == 0) {
          await Future<void>.delayed(Duration.zero);
        }
        final renaming = notifier.renameVehicle('tucson', 'Hyundai Tucson');
        store.saveError = const FileSystemException('disk full');
        failing.complete();

        await [
          expectLater(importing, throwsA(isA<FileSystemException>())),
          expectLater(renaming, throwsA(isA<FileSystemException>())),
        ].wait;
        final vehicle = container.read(vehicleProvider('tucson'))!;
        expect(vehicle.profile?.name, 'default.json');
        expect(store.profileOf('tucson'), older);
        expect(store.files, hasLength(1));
      },
    );

    test('importing saves the file and the vehicle together', () async {
      final (container, store) = await start();

      await container
          .read(appSettingsProvider.notifier)
          .importProfile(
            'tucson',
            const PickedFile(name: 'default.json', contents: testProfileJson),
          );

      expect(store.profileOf('tucson'), testProfileJson);
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
      expect(store.files, isEmpty);
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
      store.putProfile(
        'tucson',
        const ProfileRef('default.json'),
        testProfileJson,
      );

      await container
          .read(appSettingsProvider.notifier)
          .removeProfile('tucson');

      expect(store.files, isEmpty);
      final vehicle = container.read(vehicleProvider('tucson'))!;
      expect(vehicle.profile, isNull);
      // It only chose which of the profile's requests apply.
      expect(vehicle.modelYear, isNull);
    });

    test('a removed profile can be put back', () async {
      final (container, store) = await start(
        profile: const ProfileRef('default.json'),
      );
      store.putProfile(
        'tucson',
        const ProfileRef('default.json'),
        testProfileJson,
      );
      final notifier = container.read(appSettingsProvider.notifier);
      final profile = await container.read(
        vehicleProfileProvider('tucson').future,
      ) as LoadedProfile;

      await notifier.removeProfile('tucson');
      await notifier.restoreProfile('tucson', profile, modelYear: 2023);

      expect(store.profileOf('tucson'), testProfileJson);
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
      // Its write waits for the import's.
      final renaming = notifier.renameVehicle('tucson', 'Hyundai Tucson');
      write.complete();
      await (importing, renaming).wait;

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
      final deleting = notifier.deleteVehicle('tucson');
      write.complete();
      await (importing, deleting).wait;

      expect(store.settings.vehicles, isEmpty);
      expect(store.files, isEmpty);
    });

    test('an import during a removal keeps its file', () async {
      final (container, store) = await start(
        profile: const ProfileRef('default.json'),
      );
      store.putProfile(
        'tucson',
        const ProfileRef('default.json'),
        testProfileJson,
      );
      final notifier = container.read(appSettingsProvider.notifier);
      final write = Completer<void>();
      store.nextSave = write.future;

      // The removal's settings write is held; the import comes meanwhile.
      final removing = notifier.removeProfile('tucson');
      await Future<void>.delayed(Duration.zero);
      final importing = notifier.importProfile(
        'tucson',
        const PickedFile(name: 'newer.json', contents: testProfileJson),
      );
      write.complete();
      await (removing, importing).wait;

      expect(store.profileOf('tucson'), testProfileJson);
      expect(store.settings.vehicleById('tucson')!.profile?.name, 'newer.json');
    });

    test('Undo decides once it runs, not as it\'s asked', () async {
      final (container, store) = await start(
        profile: const ProfileRef('default.json'),
      );
      store.putProfile(
        'tucson',
        const ProfileRef('default.json'),
        testProfileJson,
      );
      final notifier = container.read(appSettingsProvider.notifier);
      final profile = await container.read(
        vehicleProfileProvider('tucson').future,
      ) as LoadedProfile;
      await notifier.removeProfile('tucson');
      final write = Completer<void>();
      store.profileWrite = write.future;

      // Undo is asked while an import is still writing its file.
      final importing = notifier.importProfile(
        'tucson',
        const PickedFile(name: 'newer.json', contents: testProfileJson),
      );
      final undoing = notifier.restoreProfile(
        'tucson',
        profile,
        modelYear: 2023,
      );
      write.complete();
      await (importing, undoing).wait;

      expect(store.settings.vehicleById('tucson')!.profile?.name, 'newer.json');
    });

    test('Undo doesn\'t replace a profile imported since', () async {
      final (container, store) = await start(
        profile: const ProfileRef('default.json'),
      );
      store.putProfile(
        'tucson',
        const ProfileRef('default.json'),
        testProfileJson,
      );
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

  test('last values land on disk in the order they were read', () async {
    final storage = FakeLastValuesStorage();
    final container = ProviderContainer(
      overrides: testOverrides(
        settings: const AppSettings(
          vehicles: [Vehicle(id: 'tucson', name: 'Tucson')],
        ),
        lastValues: storage,
      ),
    );
    addTearDown(container.dispose);
    await container.read(lastValuesProvider.future);
    final notifier = container.read(lastValuesProvider.notifier);
    // The first write is slow; the second must not land before it.
    final slow = Completer<void>();
    storage.nextSave = slow.future;

    final first = notifier.record(
      'tucson',
      {'rpm': 800},
      DateTime(2026, 11, 3, 10),
      seq: 1,
    );
    await Future<void>.delayed(Duration.zero);
    final second = notifier.record(
      'tucson',
      {'rpm': 900},
      DateTime(2026, 11, 3, 10, 1),
      seq: 2,
    );
    slow.complete();
    await (first, second).wait;

    expect(storage.saved.byVehicle['tucson']!['rpm']!.value, 900);
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

  group('a failed write', () {
    Future<(ProviderContainer, FakeSettingsStore)> start() async {
      final store = FakeSettingsStore(
        settings: const AppSettings(
          vehicles: [Vehicle(id: 'tucson', name: 'A')],
        ),
      );
      final container = ProviderContainer(
        overrides: testOverrides(store: store),
      );
      addTearDown(container.dispose);
      await container.read(appSettingsProvider.future);
      return (container, store);
    }

    String name(ProviderContainer c) => c.read(vehicleProvider('tucson'))!.name;

    test('puts back the settings on disk', () async {
      final (container, store) = await start();
      final failing = Completer<void>();
      store.nextSave = failing.future;

      final renaming = container
          .read(appSettingsProvider.notifier)
          .renameVehicle('tucson', 'B');
      expect(name(container), 'B');
      failing.completeError(const FileSystemException('disk full'));

      await expectLater(renaming, throwsA(isA<FileSystemException>()));
      expect(name(container), 'A');
    });

    test('fails every change it held, and puts them all back', () async {
      final (container, store) = await start();
      final notifier = container.read(appSettingsProvider.notifier);
      final failing = Completer<void>();
      store.nextSave = failing.future;

      // Both before the write starts: one write holds them.
      final first = notifier.renameVehicle('tucson', 'B');
      final second = notifier.renameVehicle('tucson', 'C');
      failing.completeError(const FileSystemException('disk full'));

      await expectLater(first, throwsA(isA<FileSystemException>()));
      await expectLater(second, throwsA(isA<FileSystemException>()));
      expect(name(container), 'A');
      expect(store.settings.vehicleById('tucson')!.name, 'A');
    });

    test('if the next write fails too, both changes fail', () async {
      final (container, store) = await start();
      final notifier = container.read(appSettingsProvider.notifier);
      final failing = Completer<void>();
      store.nextSave = failing.future;

      final first = notifier.renameVehicle('tucson', 'B');
      // The write of B is under way; C comes during it.
      await Future<void>.delayed(Duration.zero);
      final second = notifier.renameVehicle('tucson', 'C');
      store.saveError = const FileSystemException('disk full');
      failing.complete();

      await [
        expectLater(first, throwsA(isA<FileSystemException>())),
        expectLater(second, throwsA(isA<FileSystemException>())),
      ].wait;
      expect(name(container), 'A');
      expect(store.settings.vehicleById('tucson')!.name, 'A');
    });

    test('a change during it is written next, for both', () async {
      final (container, store) = await start();
      final notifier = container.read(appSettingsProvider.notifier);
      final failing = Completer<void>();
      store.nextSave = failing.future;

      final first = notifier.renameVehicle('tucson', 'B');
      // The write of B is under way.
      await Future<void>.delayed(Duration.zero);
      final second = notifier.renameVehicle('tucson', 'C');
      failing.completeError(const FileSystemException('disk full'));

      // The next write holds B too, and it lands: so did B.
      await (first, second).wait;
      expect(name(container), 'C');
      expect(store.settings.vehicleById('tucson')!.name, 'C');
      expect(store.saves, 2);
    });
  });

  test('files that can\'t be deleted don\'t fail what was saved', () async {
    final store =
        FakeSettingsStore(
            settings: const AppSettings(
              vehicles: [
                Vehicle(
                  id: 'tucson',
                  name: 'A',
                  profile: ProfileRef('default.json'),
                ),
              ],
            ),
          )
          ..putProfile(
            'tucson',
            const ProfileRef('default.json'),
            testProfileJson,
          )
          ..deleteError = const FileSystemException('busy');
    final container = ProviderContainer(overrides: testOverrides(store: store));
    addTearDown(container.dispose);
    await container.read(appSettingsProvider.future);
    final notifier = container.read(appSettingsProvider.notifier);
    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);

    // The import's settings land; the old file stays, and that's reported.
    await notifier.importProfile(
      'tucson',
      const PickedFile(name: 'newer.json', contents: testProfileJson),
    );
    expect(store.settings.vehicleById('tucson')!.profile?.name, 'newer.json');

    await notifier.deleteVehicle('tucson');
    expect(store.settings.vehicles, isEmpty);
    expect(reported, hasLength(2));
  });

  test('a webhook that can\'t be read can be entered again', () async {
    final store = FakeSettingsStore()..webhookError = StateError('keystore');
    final container = ProviderContainer(overrides: testOverrides(store: store));
    addTearDown(container.dispose);
    final previous = FlutterError.onError;
    FlutterError.onError = (_) {};
    addTearDown(() => FlutterError.onError = previous);

    final settings = await container.read(webhookProvider.future);
    expect(settings.saved, WebhookTarget.none);
    expect(settings.unreadable, isTrue);

    // Read again once storage recovers, it's there.
    store
      ..webhookError = null
      ..webhook = const WebhookTarget('https://example.com/api/webhook/old');
    container.read(webhookProvider.notifier).reload();
    final again = await container.read(webhookProvider.future);
    expect(again.saved.url, 'https://example.com/api/webhook/old');
    expect(again.unreadable, isFalse);
    store
      ..webhookError = StateError('keystore')
      ..webhook = WebhookTarget.none;
    container.read(webhookProvider.notifier).reload();
    await container.read(webhookProvider.future);

    final notifier = container.read(webhookProvider.notifier);
    await notifier.editUrl('https://example.com/api/webhook/x');
    await notifier.save();
    expect(store.webhook.url, 'https://example.com/api/webhook/x');
  });

  test('last values that couldn\'t be loaded keep nothing', () async {
    final storage = FakeLastValuesStorage()..loadError = StateError('broken');
    final container = ProviderContainer(
      overrides: testOverrides(
        settings: const AppSettings(
          vehicles: [Vehicle(id: 'tucson', name: 'A')],
        ),
        lastValues: storage,
      ),
    );
    addTearDown(container.dispose);

    await container
        .read(lastValuesProvider.notifier)
        .record('tucson', {'rpm': 800}, DateTime(2026, 11, 3), seq: 1);

    expect(storage.saves, 0);
  });

  test('a connection notes what the adapter can do', () async {
    final store = FakeSettingsStore(
      settings: const AppSettings(
        vehicles: [
          Vehicle(
            id: 'tucson',
            name: 'A',
            adapter: VehicleAdapter(
              address: 'A',
              name: 'OBDII',
              type: AdapterType.classic,
            ),
          ),
        ],
      ),
    );
    final container = ProviderContainer(overrides: testOverrides(store: store));
    addTearDown(container.dispose);

    await container
        .read(appSettingsProvider.notifier)
        .markConnected('tucson', DateTime(2026, 11, 3), setsFlowControl: false);

    final vehicle = store.settings.vehicleById('tucson')!;
    expect(vehicle.adapter?.setsFlowControl, isFalse);
    expect(vehicle.lastSeen, DateTime(2026, 11, 3));
  });

  test('noting when a vehicle was seen never throws', () async {
    final store = FakeSettingsStore(
      settings: const AppSettings(
        vehicles: [Vehicle(id: 'tucson', name: 'A')],
      ),
    )..saveError = const FileSystemException('disk full');
    final container = ProviderContainer(overrides: testOverrides(store: store));
    addTearDown(container.dispose);
    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);

    await container
        .read(appSettingsProvider.notifier)
        .markConnected('tucson', DateTime(2026, 11, 3), setsFlowControl: true);

    expect(reported.single.library, 'settings');
    expect(container.read(vehicleProvider('tucson'))!.lastSeen, isNull);
  });
}
