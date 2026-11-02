import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pitwall/app/app.dart';
import 'package:pitwall/core/bluetooth/classic_bluetooth.dart';
import 'package:pitwall/core/platform/permission_gateway.dart';
import 'package:pitwall/core/settings/settings.dart';
import 'package:pitwall/core/vehicles/vehicle.dart';
import 'package:pitwall/features/home/widgets/vehicle_hero_card.dart';
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

    expect(
      find.descendant(
        of: find.byType(VehicleHeroCard),
        matching: find.text('Tucson'),
      ),
      findsOneWidget,
    );
    expect(find.text('Waiting for the car'), findsOneWidget);
    // The webhook and head unit aren't set yet.
    expect(find.text('Finish setting up'), findsOneWidget);
    expect(find.byType(FloatingNavBar), findsOneWidget);

    // Below the checklist and the vehicle, on the small test screen.
    await tester.scrollUntilVisible(
      find.text('Ready to send'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Ready to send'), findsOneWidget);
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
    expect(find.text('Background checks'), findsOneWidget);
    // Trip start lives on each vehicle now.
    expect(find.text('What wakes Pitwall'), findsNothing);
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
    expect(find.text('Finish setting up'), findsOneWidget);
    expect(find.text('Add a vehicle'), findsOneWidget);
  });

  testWidgets('a tab page scrolls its last item clear of the nav bar', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      settings: const AppSettings(vehicles: [_tucson], setupDone: true),
    );
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).last, const Offset(0, -2000));
    await tester.pumpAndSettle();

    final last = tester.getRect(find.text('Developer tools'));
    final bar = tester.getRect(find.byType(FloatingNavBar));
    expect(last.bottom, lessThan(bar.top));
  });

  testWidgets('the vehicle list ends with a slot for adding another', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      settings: const AppSettings(vehicles: [_tucson], setupDone: true),
    );
    await tester.tap(find.text('Vehicles'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.tap(find.text('Add vehicle'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingNavBar), findsNothing);
  });

  testWidgets('values to send are searchable from the top bar', (tester) async {
    await _pumpApp(
      tester,
      settings: const AppSettings(vehicles: [_tucson], setupDone: true),
    );
    await tester.tap(find.text('Vehicles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tucson'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Values to send'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search values'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'coolant');
    await tester.pumpAndSettle();

    // The page stays underneath the search view, so each value appears
    // once there, and once more in the view when it matches.
    expect(find.text('coolant_temp_c'), findsNWidgets(2));
    expect(find.text('rpm'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No values match "zzz".'), findsOneWidget);
  });

  testWidgets('a pinned action stays above the keyboard', (tester) async {
    await _pumpApp(tester, settings: const AppSettings(setupDone: true));
    await tester.tap(find.text('Vehicles'));
    await tester.pumpAndSettle();
    // On the small test screen the card's button starts under the floating
    // navigation bar; scroll it into view, as a person would.
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add vehicle'));
    await tester.pumpAndSettle();
    expect(find.text('Name this vehicle'), findsOneWidget);

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    const keyboard = 300.0;
    tester.view.viewInsets = FakeViewPadding(
      bottom: keyboard * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    final button = tester.getRect(find.byType(GlassButton));
    expect(button.bottom, lessThanOrEqualTo(screen.height - keyboard));
  });

  testWidgets(
    'with several vehicles, the vehicle name on Home switches between them',
    (tester) async {
      await _pumpApp(
        tester,
        settings: AppSettings(
          vehicles: [
            _tucson.copyWith(lastSeen: DateTime(2026, 11, 1)),
            const Vehicle(id: 'mazda', name: 'Mazda', adapterAddress: 'BB'),
          ],
          setupDone: true,
        ),
      );
      expect(find.text('Tucson'), findsWidgets);

      // Below the setup checklist on the small test screen.
      final arrow = find.byIcon(Icons.arrow_drop_down);
      await Scrollable.ensureVisible(tester.element(arrow), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(arrow);
      await tester.pumpAndSettle();
      expect(find.text('Show on Home'), findsOneWidget);
      expect(find.text('Never connected'), findsOneWidget);

      await tester.tap(find.text('Mazda'));
      await tester.pumpAndSettle();
      expect(find.text('Show on Home'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(VehicleHeroCard),
          matching: find.text('Mazda'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('a vehicle\'s trip start has its own page', (tester) async {
    await _pumpApp(
      tester,
      settings: const AppSettings(vehicles: [_tucson], setupDone: true),
    );
    await tester.tap(find.text('Vehicles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tucson'));
    await tester.pumpAndSettle();
    expect(find.text('Choose the car\'s Bluetooth'), findsOneWidget);

    await tester.tap(find.text('Trip start'));
    await tester.pumpAndSettle();
    expect(find.text('Car head unit'), findsOneWidget);
    expect(find.text('Not chosen yet'), findsOneWidget);
  });

  testWidgets('a new vehicle is offered its trip start right away', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(
          settings: const AppSettings(setupDone: true),
          bluetooth: FakeBluetoothGateway(
            devices: const [BondedDevice(name: 'OBDII', address: 'A')],
          ),
        ),
        child: const PitwallApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vehicles'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add vehicle'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Mazda');
    await tester.tap(find.text('OBDII'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(GlassButton, 'Add vehicle'));
    await tester.pumpAndSettle();
    expect(find.text('Choose Mazda\'s Bluetooth?'), findsOneWidget);

    await tester.tap(find.text('Choose now'));
    await tester.pumpAndSettle();
    expect(find.text('Car head unit'), findsOneWidget);
  });

}
