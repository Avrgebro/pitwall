import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pitwall/app/app.dart';
import 'package:pitwall/core/platform/permission_gateway.dart';
import 'package:pitwall/core/settings/settings.dart';
import 'package:pitwall/core/vehicles/vehicle.dart';
import 'package:pitwall/ui/ui.dart';

import '../helpers/fakes.dart';

const _tucson = Vehicle(
  id: 'tucson',
  name: 'Tucson',
  adapterAddress: '00:1D:A5:68:98:8B',
  adapterName: 'vLinker MC+',
);

Future<void> _pumpApp(
  WidgetTester tester, {
  AppSettings settings = const AppSettings(),
  Map<AppPermission, bool>? permissions,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: testOverrides(settings: settings, permissions: permissions),
      child: const PitwallApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('before setup, the app opens on the welcome step', (
    tester,
  ) async {
    await _pumpApp(tester);

    expect(find.text('Your car\'s data, in Home Assistant'), findsOneWidget);
    expect(find.text('Step 1 of 5'), findsOneWidget);
    expect(find.byType(FloatingNavBar), findsNothing);
  });

  testWidgets('after setup, Home shows the vehicle waiting for the car', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      settings: const AppSettings(vehicles: [_tucson], setupDone: true),
    );

    expect(find.text('Tucson'), findsOneWidget);
    expect(find.text('Waiting for the car'), findsOneWidget);
    expect(find.text('Ready to send'), findsOneWidget);
    expect(find.byType(FloatingNavBar), findsOneWidget);
  });

  testWidgets('tabs switch between Home, Vehicles and Settings', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      settings: const AppSettings(vehicles: [_tucson], setupDone: true),
    );

    await tester.tap(find.text('Vehicles'));
    await tester.pumpAndSettle();
    expect(find.text('vLinker MC+'), findsOneWidget);

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.text('What wakes Pitwall'), findsOneWidget);
  });

  testWidgets('a vehicle opens its detail screen above the tabs', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      settings: const AppSettings(vehicles: [_tucson], setupDone: true),
    );

    await tester.tap(find.text('Vehicles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tucson'));
    await tester.pumpAndSettle();

    expect(find.text('Standard values only'), findsOneWidget);
    expect(find.byType(FloatingNavBar), findsNothing);
  });

  testWidgets('missing permissions put a dot on the Settings tab', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      settings: const AppSettings(vehicles: [_tucson], setupDone: true),
      permissions: {
        AppPermission.bluetooth: true,
        AppPermission.notifications: false,
        AppPermission.batteryOptimisation: true,
      },
    );

    final badges = tester.widgetList<Badge>(find.byType(Badge));
    expect(badges.any((badge) => badge.isLabelVisible), isTrue);
  });

  testWidgets('without vehicles, Vehicles invites adding one', (tester) async {
    await _pumpApp(tester, settings: const AppSettings(setupDone: true));

    await tester.tap(find.text('Vehicles'));
    await tester.pumpAndSettle();

    expect(find.text('No vehicles yet'), findsOneWidget);
    expect(
      find.text('Any ELM327-compatible Bluetooth adapter works.'),
      findsOneWidget,
    );
  });

  testWidgets('each setting opens its own page', (tester) async {
    await _pumpApp(
      tester,
      settings: const AppSettings(vehicles: [_tucson], setupDone: true),
    );

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.text('Webhook URL'), findsNothing);

    await tester.tap(find.text('Webhook'));
    await tester.pumpAndSettle();
    expect(find.text('Webhook URL'), findsOneWidget);
    expect(find.byType(FloatingNavBar), findsNothing);
  });

  testWidgets('a vehicle setting opens its own page', (tester) async {
    await _pumpApp(
      tester,
      settings: const AppSettings(vehicles: [_tucson], setupDone: true),
    );

    await tester.tap(find.text('Vehicles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tucson'));
    await tester.pumpAndSettle();
    expect(find.text('Sent as tucson'), findsOneWidget);

    await tester.tap(find.text('Vehicle profile'));
    await tester.pumpAndSettle();
    expect(find.text('Import profile'), findsOneWidget);
  });

  testWidgets('tabs are Vehicles, Home, Settings, opening on Home', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      settings: const AppSettings(vehicles: [_tucson], setupDone: true),
    );

    final bar = tester.widget<FloatingNavBar>(find.byType(FloatingNavBar));
    expect(bar.destinations.map((d) => d.label), [
      'Vehicles',
      'Home',
      'Settings',
    ]);
    expect(bar.selectedIndex, 1);
  });

  testWidgets('setup can skip the vehicle and webhook for later', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set up later'));
    await tester.pumpAndSettle();
    expect(find.text('Three permissions'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set up later'));
    await tester.pumpAndSettle();
    expect(find.text('Almost there'), findsOneWidget);
    expect(find.text('Not added yet'), findsOneWidget);
    expect(find.text('Not set yet'), findsOneWidget);

    await tester.tap(find.text('Go to Home'));
    await tester.pumpAndSettle();
    expect(find.text('No vehicles yet'), findsOneWidget);
  });
}
