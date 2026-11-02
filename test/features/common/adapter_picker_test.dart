import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pitwall/core/bluetooth/bluetooth_gateway.dart';
import 'package:pitwall/core/bluetooth/device_kind.dart';
import 'package:pitwall/core/platform/permission_gateway.dart';
import 'package:pitwall/features/common/widgets/adapter_picker.dart';
import 'package:pitwall/state/permissions_state.dart';
import 'package:pitwall/ui/ui.dart';

import '../../helpers/fakes.dart';

const _adapter = BondedDevice(name: 'vLinker MC+', address: 'A');

BondedDevice _audio(int i) =>
    BondedDevice(name: 'Earbuds $i', address: 'E$i', kind: DeviceKind.audio);

Future<void> _pump(
  WidgetTester tester,
  List<BondedDevice> devices, {
  String? selected,
  String? Function(String address)? ownerOf,
  Map<AppPermission, bool>? permissions,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: testOverrides(
        bluetooth: FakeBluetoothGateway(devices: devices),
        permissions: permissions,
      ),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AdapterPicker(
              selectedAddress: selected,
              ownerOf: ownerOf,
              onSelected: (_) {},
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
    await tester.tap(find.text('Show 2 more'));
    await tester.pumpAndSettle();
    expect(find.text('Earbuds 1'), findsOneWidget);

    await tester.tap(find.text('Hide 2 devices'));
    await tester.pumpAndSettle();
    expect(find.text('Earbuds 1'), findsNothing);
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
}
