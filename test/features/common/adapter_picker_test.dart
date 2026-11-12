import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pitwall/core/bluetooth/adapter_type.dart';
import 'package:pitwall/core/bluetooth/bluetooth_gateway.dart';
import 'package:pitwall/core/bluetooth/device_kind.dart';
import 'package:pitwall/core/platform/permission_gateway.dart';
import 'package:pitwall/features/common/widgets/adapter_picker.dart';
import 'package:pitwall/state/permissions_state.dart';
import 'package:pitwall/ui/ui.dart';

import '../../helpers/fakes.dart';

const _adapter = BluetoothDevice(
  name: 'vLinker MC+',
  address: 'A',
  type: AdapterType.classic,
);

BluetoothDevice _audio(int i) => BluetoothDevice(
  name: 'Earbuds $i',
  address: 'E$i',
  kind: DeviceKind.audio,
  type: AdapterType.classic,
);

Future<void> _pump(
  WidgetTester tester,
  List<BluetoothDevice> devices, {
  String? selected,
  String? Function(String address)? ownerOf,
  Map<AppPermission, bool>? permissions,
  DeviceRole role = DeviceRole.adapter,
  FakeBluetoothGateway? bluetooth,
  ValueChanged<BluetoothDevice>? onSelected,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: testOverrides(
        bluetooth: bluetooth ?? FakeBluetoothGateway(devices: devices),
        permissions: permissions,
      ),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AdapterPicker(
              selectedAddress: selected,
              role: role,
              ownerOf: ownerOf,
              onSelected: onSelected ?? (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('likely adapters come first; other devices fold away', (
    tester,
  ) async {
    await _pump(tester, [_audio(1), _adapter, _audio(2)]);

    expect(find.text('vLinker MC+'), findsOneWidget);
    expect(find.text('Earbuds 1'), findsNothing);
    await tester.tap(find.text('Show 2 devices'));
    await tester.pumpAndSettle();
    expect(find.text('Earbuds 1'), findsOneWidget);

    await tester.tap(find.text('Hide 2 devices'));
    await tester.pumpAndSettle();
    expect(find.text('Earbuds 1'), findsNothing);
  });

  testWidgets('a single other device is one device', (tester) async {
    await _pump(tester, [_adapter, _audio(1)]);

    expect(find.text('Show 1 device'), findsOneWidget);
  });

  testWidgets('a chosen device among the others keeps them open', (
    tester,
  ) async {
    await _pump(tester, [_adapter, _audio(1)], selected: 'E1');

    expect(find.text('Earbuds 1'), findsOneWidget);
  });

  testWidgets('five devices or fewer need no filter', (tester) async {
    await _pump(tester, [_adapter, for (var i = 0; i < 4; i++) _audio(i)]);
    expect(find.byType(SearchBar), findsNothing);
  });

  testWidgets('more than five devices get a filter', (tester) async {
    await _pump(tester, [_adapter, for (var i = 0; i < 5; i++) _audio(i)]);
    expect(find.byType(SearchBar), findsOneWidget);

    await tester.enterText(find.byType(SearchBar), 'earbuds 3');
    await tester.pumpAndSettle();
    expect(find.text('Earbuds 3'), findsOneWidget);
    expect(find.text('vLinker MC+'), findsNothing);
  });

  testWidgets('a filter stays in view while it filters', (tester) async {
    final devices = [_adapter, for (var i = 0; i < 5; i++) _audio(i)];
    await _pump(tester, devices);
    await tester.enterText(find.byType(SearchBar), 'earbuds 3');
    await tester.pumpAndSettle();

    // Fewer devices than need a filter, as after unpairing some.
    devices.removeRange(2, devices.length);
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();

    expect(find.byType(SearchBar), findsOneWidget);
    expect(find.text('earbuds 3'), findsOneWidget);
    expect(find.text('No devices match "earbuds 3".'), findsOneWidget);
  });

  testWidgets('a device another vehicle uses is shown but not offered', (
    tester,
  ) async {
    await _pump(tester, [
      _adapter,
    ], ownerOf: (address) => address == 'A' ? 'Mazda' : null);

    expect(find.text('Used by Mazda'), findsOneWidget);
    final row = tester.widget<ChoiceRow<String>>(
      find.byType(ChoiceRow<String>),
    );
    expect(row.enabled, isFalse);
  });

  testWidgets('granting Bluetooth here counts everywhere', (tester) async {
    await _pump(
      tester,
      [_adapter],
      permissions: {
        for (final permission in AppPermission.values)
          permission: permission != AppPermission.bluetooth,
      },
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AdapterPicker)),
    );
    // Settings and setup read this; it no longer says Bluetooth is missing.
    expect(container.read(missingPermissionsProvider), 0);
    expect(find.text('vLinker MC+'), findsOneWidget);
  });

  testWidgets('an adapter says how it connects, in a badge', (tester) async {
    await _pump(tester, [_adapter]);
    expect(find.text('Classic'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('a head unit shows just its address', (tester) async {
    await _pump(tester, [
      const BluetoothDevice(
        name: 'TUCSON BT',
        address: 'B',
        kind: DeviceKind.audio,
        type: AdapterType.classic,
      ),
    ], role: DeviceRole.headUnit);
    expect(find.text('B'), findsOneWidget);
    // How a stereo connects doesn't matter: no badge.
    expect(find.text('Classic'), findsNothing);
  });

  group('Bluetooth LE adapters nearby', () {
    const iCar = BluetoothDevice(
      name: 'IOS-Vlink',
      address: 'C0:FF:EE:00:00:01',
      kind: DeviceKind.obdAdapter,
      type: AdapterType.ble,
    );
    const watch = BluetoothDevice(
      name: 'Galaxy Watch',
      address: 'C0:FF:EE:00:00:02',
      kind: DeviceKind.bluetoothLe,
      type: AdapterType.ble,
    );

    testWidgets('join the paired ones, saying how they connect', (
      tester,
    ) async {
      final bluetooth = FakeBluetoothGateway(devices: [_adapter])
        ..nearby = [iCar, watch];
      BluetoothDevice? chosen;
      await _pump(
        tester,
        const [],
        bluetooth: bluetooth,
        onSelected: (device) => chosen = device,
      );

      expect(
        find.text('Looking for Bluetooth LE adapters nearby'),
        findsOneWidget,
      );
      expect(find.text('IOS-Vlink'), findsOneWidget);
      expect(find.text('BLE'), findsOneWidget);
      expect(find.text('C0:FF:EE:00:00:01'), findsOneWidget);
      // Not named like an adapter: folded away with the other devices.
      expect(find.text('Galaxy Watch'), findsNothing);

      await tester.tap(find.text('IOS-Vlink'));
      expect(chosen?.type, AdapterType.ble);
    });

    testWidgets('are looked for only while the picker is open', (tester) async {
      final bluetooth = FakeBluetoothGateway(devices: [_adapter])
        ..nearby = [iCar];
      await _pump(tester, const [], bluetooth: bluetooth);
      expect(bluetooth.scanning, isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      expect(bluetooth.scanning, isFalse);
    });

    testWidgets('aren\'t looked for when choosing a head unit', (tester) async {
      final bluetooth = FakeBluetoothGateway(devices: [_adapter])
        ..nearby = [iCar];
      await _pump(
        tester,
        const [],
        bluetooth: bluetooth,
        role: DeviceRole.headUnit,
      );

      expect(bluetooth.scanning, isFalse);
      expect(find.text('IOS-Vlink'), findsNothing);
    });
  });
}
