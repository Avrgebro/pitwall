import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pitwall/app/app.dart';
import 'package:pitwall/core/bluetooth/adapter_type.dart';
import 'package:pitwall/core/bluetooth/bluetooth_gateway.dart';
import 'package:pitwall/core/platform/permission_gateway.dart';
import 'package:pitwall/core/profiles/profile_ref.dart';
import 'package:pitwall/core/settings/settings.dart';
import 'package:pitwall/core/vehicles/vehicle.dart';
import 'package:pitwall/features/home/widgets/vehicle_hero_card.dart';
import 'package:pitwall/ui/ui.dart';

import '../core/settings/fake_settings_store.dart';
import '../helpers/fakes.dart';

const _tucson = Vehicle(
  id: 'tucson',
  name: 'Tucson',
  adapter: VehicleAdapter(
    address: '00:1D:A5:68:98:8B',
    name: 'vLinker MC+',
    type: AdapterType.classic,
  ),
);

Future<void> _pumpApp(
  WidgetTester tester, {
  AppSettings settings = const AppSettings(),
  Map<AppPermission, bool>? permissions,
  FakeBluetoothGateway? bluetooth,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: testOverrides(
        settings: settings,
        permissions: permissions,
        bluetooth: bluetooth,
      ),
      child: const PitwallApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Whether the navigation bar's [label] tab shows its dot.
bool _badge(WidgetTester tester, String label) => tester
    .widget<FloatingNavBar>(find.byType(FloatingNavBar))
    .destinations
    .firstWhere((d) => d.label == label)
    .showBadge;

void main() {
  testWidgets('settings that can\'t be read stop the app, not set it up', (
    tester,
  ) async {
    final store = FakeSettingsStore(
      settings: const AppSettings(vehicles: [_tucson], setupDone: true),
    )..loadError = const FileSystemException('I/O error');
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(store: store),
        child: const PitwallApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('couldn\'t read its settings'), findsOneWidget);
    expect(find.text('Step 1 of 5'), findsNothing);

    // Readable again: the app starts as it was.
    store.loadError = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Tucson'), findsWidgets);
    expect(store.settings.vehicles.single.id, 'tucson');
  });

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
    // With a vehicle, setup no longer shows on Home; what's missing shows
    // where it belongs, like the webhook on the delivery card.
    expect(find.text('Finish setting up'), findsNothing);
    expect(find.text('No webhook yet'), findsOneWidget);
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
    expect(find.text('Tucson'), findsOneWidget);

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.text('Permissions'), findsOneWidget);
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

    expect(_badge(tester, 'Settings'), isTrue);
  });

  testWidgets('a vehicle without a trip start puts a dot on Vehicles', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      settings: const AppSettings(vehicles: [_tucson], setupDone: true),
    );
    expect(_badge(tester, 'Vehicles'), isTrue);
    await tester.tap(find.text('Vehicles'));
    await tester.pumpAndSettle();
    expect(
      find.text('Choose the car\'s Bluetooth for trip start'),
      findsOneWidget,
    );
  });

  testWidgets('a vehicle without an adapter puts a dot on Vehicles', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      settings: const AppSettings(
        vehicles: [
          Vehicle(
            id: 'tucson',
            name: 'Tucson',
            headUnit: HeadUnit(address: 'AA', name: 'T'),
          ),
        ],
        setupDone: true,
      ),
    );
    expect(_badge(tester, 'Vehicles'), isTrue);
    await tester.tap(find.text('Vehicles'));
    await tester.pumpAndSettle();
    expect(find.text('Choose its adapter'), findsOneWidget);
  });

  testWidgets('vehicles that start on their own leave Vehicles quiet', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      settings: AppSettings(
        vehicles: [
          _tucson.copyWith(
            headUnit: HeadUnit(address: 'AA', name: 'T'),
          ),
        ],
        setupDone: true,
      ),
    );
    expect(_badge(tester, 'Vehicles'), isFalse);
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

  testWidgets('a webhook typed in setup is kept when moving on', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set up later'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Typed, with the field still focused, then straight on.
    await tester.enterText(
      find.byType(TextField).first,
      'https://example.com/api/webhook/abc',
    );
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Almost there'), findsOneWidget);
    expect(find.text('Not tested yet'), findsOneWidget);
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

    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -2000),
    );
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

    // The sections filter in place.
    expect(find.text('coolant_temp_c'), findsOneWidget);
    expect(find.text('rpm'), findsNothing);

    await tester.enterText(find.byType(TextField).last, 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No values match "zzz".'), findsOneWidget);

    // Back closes the search first, then leaves the page.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SearchBar), findsNothing);
    expect(find.text('rpm'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Values to send'), findsOneWidget);
    expect(find.text('rpm'), findsNothing);
  });

  testWidgets('a pinned action stays above the keyboard', (tester) async {
    await _pumpApp(tester, settings: const AppSettings(setupDone: true));
    await tester.tap(find.text('Vehicles'));
    await tester.pumpAndSettle();
    // On the small test screen the card's button starts under the floating
    // navigation bar; scroll it into view, as a person would.
    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -500),
    );
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
            const Vehicle(
              id: 'mazda',
              name: 'Mazda',
              adapter: VehicleAdapter(
                address: 'BB',
                name: 'BB',
                type: AdapterType.classic,
              ),
            ),
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
            devices: const [
              BondedDevice(
                name: 'OBDII',
                address: 'A',
                type: AdapterType.classic,
              ),
            ],
          ),
        ),
        child: const PitwallApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vehicles'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -500),
    );
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

  testWidgets('developer tools connect to the vehicle picked', (tester) async {
    final bluetooth = FakeBluetoothGateway();
    await _pumpApp(
      tester,
      settings: AppSettings(
        vehicles: [
          _tucson.copyWith(lastSeen: DateTime(2026, 11, 1)),
          const Vehicle(
            id: 'mazda',
            name: 'Mazda',
            adapter: VehicleAdapter(
              address: 'BB',
              name: 'Mazda OBD',
              type: AdapterType.classic,
            ),
          ),
        ],
        setupDone: true,
      ),
      bluetooth: bluetooth,
    );
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    final developer = find.text('Developer tools');
    await Scrollable.ensureVisible(tester.element(developer), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(developer);
    await tester.pumpAndSettle();

    // The car seen most recently comes first; the arrow opens the choice.
    expect(find.text('vLinker MC+'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mazda'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(bluetooth.connected, ['BB']);
  });

  testWidgets('developer tools follow the vehicle picked on Home', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      settings: AppSettings(
        vehicles: [
          _tucson.copyWith(lastSeen: DateTime(2026, 11, 1)),
          const Vehicle(
            id: 'mazda',
            name: 'Mazda',
            adapter: VehicleAdapter(
              address: 'BB',
              name: 'Mazda OBD',
              type: AdapterType.classic,
            ),
          ),
        ],
        setupDone: true,
      ),
    );
    // Home's vehicle name opens the shared picker.
    await tester.tap(find.text('Tucson'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mazda'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    final developer = find.text('Developer tools');
    await Scrollable.ensureVisible(tester.element(developer), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(developer);
    await tester.pumpAndSettle();

    expect(find.text('Mazda OBD'), findsOneWidget);
  });

  testWidgets('developer tools say when Bluetooth is off', (tester) async {
    await _pumpApp(
      tester,
      settings: const AppSettings(vehicles: [_tucson], setupDone: true),
      bluetooth: FakeBluetoothGateway(bluetoothOn: false),
    );
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    final developer = find.text('Developer tools');
    await Scrollable.ensureVisible(tester.element(developer), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(developer);
    await tester.pumpAndSettle();

    expect(
      find.text('Bluetooth is off. Turn it on to connect.'),
      findsOneWidget,
    );
    final connect = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Connect'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    final simulate = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Simulate auto-start'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    expect(connect.onPressed, isNull);
    expect(simulate.onPressed, isNull);
  });

  testWidgets('a vehicle row shows its state, not its setup details', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      settings: AppSettings(
        vehicles: [
          _tucson.copyWith(
            headUnit: HeadUnit(address: 'AA', name: 'T'),

            lastSeen: testNow.subtract(const Duration(hours: 2)),
          ),
        ],
        setupDone: true,
      ),
    );
    await tester.tap(find.text('Vehicles'));
    await tester.pumpAndSettle();

    expect(find.text('Last seen 2 h ago'), findsOneWidget);
    // The adapter is on the vehicle's page, not the list.
    expect(find.text('vLinker MC+'), findsNothing);
  });

  testWidgets('a profile that can\'t be read says so', (tester) async {
    await _pumpApp(
      tester,
      settings: AppSettings(
        // The vehicle says it has a profile, but there's no file for it.
        vehicles: [
          _tucson.withProfile(
            const ProfileRef('default.json'),
            modelYear: null,
          ),
        ],
        setupDone: true,
      ),
    );
    await tester.tap(find.text('Vehicles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tucson'));
    await tester.pumpAndSettle();

    expect(find.text('OBDb profile can\'t be read'), findsOneWidget);
    await tester.tap(find.text('Vehicle profile'));
    await tester.pumpAndSettle();
    expect(find.text('Profile can\'t be read'), findsOneWidget);
    expect(find.text('Import again'), findsOneWidget);
  });

  testWidgets('licences open in the app\'s own pages', (tester) async {
    LicenseRegistry.addLicense(
      () => Stream.value(
        const LicenseEntryWithLineBreaks(['zz_test_package'], 'Test licence'),
      ),
    );
    await _pumpApp(tester, settings: const AppSettings(setupDone: true));
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    final about = find.text('About Pitwall');
    await Scrollable.ensureVisible(tester.element(about), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(about);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open-source libraries'));
    await tester.pumpAndSettle();

    final package = find.text('zz_test_package');
    await tester.scrollUntilVisible(
      package,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(package);
    await tester.pumpAndSettle();
    expect(find.text('Test licence'), findsOneWidget);
    expect(find.byType(LicensePage), findsNothing);
  });
}
