import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pitwall/core/profiles/profile_ref.dart';
import 'package:pitwall/core/readings/last_values.dart';
import 'package:pitwall/core/readings/unreported.dart';
import 'package:pitwall/core/settings/settings.dart';
import 'package:pitwall/core/vehicles/vehicle.dart';
import 'package:pitwall/features/vehicles/values_to_send_screen.dart';
import 'package:pitwall/features/vehicles/vehicle_adapter_screen.dart';
import 'package:pitwall/features/vehicles/vehicle_detail_screen.dart';
import 'package:pitwall/features/vehicles/vehicle_name_screen.dart';
import 'package:pitwall/features/vehicles/vehicle_profile_screen.dart';
import 'package:pitwall/features/vehicles/vehicle_trip_start_screen.dart';
import 'package:pitwall/ui/ui.dart';

import '../../core/profiles/test_profile.dart';
import '../../core/settings/fake_settings_store.dart';
import '../../helpers/fakes.dart';

void main() {
  final screens = <String, Widget>{
    'Vehicle': const VehicleDetailScreen(vehicleId: 'gone'),
    'Values to send': const ValuesToSendScreen(vehicleId: 'gone'),
    'Trip start': const VehicleTripStartScreen(vehicleId: 'gone'),
    'Vehicle profile': const VehicleProfileScreen(vehicleId: 'gone'),
    'Adapter': const VehicleAdapterScreen(vehicleId: 'gone'),
    'Name': const VehicleNameScreen(vehicleId: 'gone'),
  };

  for (final MapEntry(key: title, value: screen) in screens.entries) {
    testWidgets('$title says when its vehicle is gone', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: testOverrides(),
          child: MaterialApp(theme: AppTheme.light(), home: screen),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(title), findsOneWidget);
      expect(find.text('This vehicle was removed.'), findsOneWidget);
    });
  }

  testWidgets('a vehicle page says when the settings can\'t be read', (
    tester,
  ) async {
    final store = FakeSettingsStore()..loadError = StateError('broken');
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(store: store),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const VehicleDetailScreen(vehicleId: 'tucson'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Couldn\'t read the settings.'), findsOneWidget);
  });

  testWidgets('a value sent but not reported says why', (tester) async {
    final lastValues = FakeLastValuesStorage()
      ..saved = const LastValues().noteUnreported('tucson', {
        'rpm': Unreported.noAnswer,
      }, testNow.subtract(const Duration(minutes: 3)));
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(
          settings: const AppSettings(
            vehicles: [Vehicle(id: 'tucson', name: 'Tucson')],
          ),
          lastValues: lastValues,
        ),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ValuesToSendScreen(vehicleId: 'tucson'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('The car didn\'t answer its request, 3 min ago'),
      findsOneWidget,
    );
  });

  group('with a profile', () {
    Future<void> pump(WidgetTester tester, Widget screen) async {
      final store =
          FakeSettingsStore(
            settings: const AppSettings(
              vehicles: [
                Vehicle(
                  id: 'tucson',
                  name: 'Tucson',
                  modelYear: 2023,
                  profile: ProfileRef('default.json'),
                ),
              ],
            ),
          )..putProfile(
            'tucson',
            const ProfileRef('default.json'),
            testProfileJson,
          );
      await tester.pumpWidget(
        ProviderScope(
          overrides: testOverrides(store: store),
          child: MaterialApp(theme: AppTheme.light(), home: screen),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the profile page says what it adds and what it can\'t', (
      tester,
    ) async {
      await pump(tester, const VehicleProfileScreen(vehicleId: 'tucson'));

      expect(find.text('3 values your car can report'), findsOneWidget);
      expect(find.text('Fuel'), findsOneWidget);
      expect(find.text('Trips'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Never sent'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Not readable yet'), findsOneWidget);
      expect(
        find.text('3 requests would change something in the car'),
        findsOneWidget,
      );
    });

    testWidgets('values can be shown for one category', (tester) async {
      await pump(
        tester,
        const ValuesToSendScreen(vehicleId: 'tucson', category: 'Trips'),
      );

      expect(find.text('Trips'), findsOneWidget);
      expect(find.text('test_odo_mi'), findsOneWidget);
      expect(find.text('test_fuel_vol'), findsNothing);
      expect(find.text('rpm'), findsNothing);
    });
  });

  group('saving', () {
    Future<FakeSettingsStore> pump(WidgetTester tester, Widget screen) async {
      final store =
          FakeSettingsStore(
            settings: const AppSettings(
              vehicles: [
                Vehicle(
                  id: 'tucson',
                  name: 'Tucson',
                  modelYear: 2023,
                  profile: ProfileRef('default.json'),
                ),
              ],
            ),
          )..putProfile(
            'tucson',
            const ProfileRef('default.json'),
            testProfileJson,
          );
      await tester.pumpWidget(
        ProviderScope(
          overrides: testOverrides(store: store),
          child: MaterialApp(theme: AppTheme.light(), home: screen),
        ),
      );
      await tester.pumpAndSettle();
      return store;
    }

    testWidgets('a name is saved when typing is done, not on each key', (
      tester,
    ) async {
      final store = await pump(
        tester,
        const VehicleNameScreen(vehicleId: 'tucson'),
      );

      await tester.enterText(find.byType(TextField), 'Hyundai Tucson');
      await tester.pump();
      expect(store.settings.vehicles.single.name, 'Tucson');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(store.settings.vehicles.single.name, 'Hyundai Tucson');
    });

    testWidgets('a name is saved as the app goes to the background', (
      tester,
    ) async {
      final store = await pump(
        tester,
        const VehicleNameScreen(vehicleId: 'tucson'),
      );

      await tester.enterText(find.byType(TextField), 'Hyundai Tucson');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pumpAndSettle();

      expect(store.settings.vehicles.single.name, 'Hyundai Tucson');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    testWidgets(
      'a name is saved when the screen goes, with the field focused',
      (tester) async {
        final store = await pump(
          tester,
          const VehicleNameScreen(vehicleId: 'tucson'),
        );

        await tester.enterText(find.byType(TextField), 'Hyundai Tucson');
        // Replaced without a pop, as when another route takes over.
        await tester.pumpWidget(
          ProviderScope(
            overrides: testOverrides(store: store),
            child: const MaterialApp(key: ValueKey('other'), home: SizedBox()),
          ),
        );
        await tester.pumpAndSettle();

        expect(store.settings.vehicles.single.name, 'Hyundai Tucson');
      },
    );

    testWidgets('a removed profile comes back with Undo', (tester) async {
      final store = await pump(
        tester,
        const VehicleProfileScreen(vehicleId: 'tucson'),
      );

      await tester.tap(find.byTooltip('Remove profile'));
      await tester.pumpAndSettle();
      expect(store.files, isEmpty);
      expect(find.text('Profile removed'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(store.profileOf('tucson'), testProfileJson);
      expect(store.settings.vehicles.single.modelYear, 2023);
    });
  });
}
