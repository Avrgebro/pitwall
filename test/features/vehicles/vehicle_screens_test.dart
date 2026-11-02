import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/settings/settings.dart';
import 'package:pitwall/core/vehicles/vehicle.dart';
import 'package:material_ui/material_ui.dart';
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

  group('with a profile', () {
    Future<void> pump(WidgetTester tester, Widget screen) async {
      final store = FakeSettingsStore(
        settings: const AppSettings(
          vehicles: [
            Vehicle(
              id: 'tucson',
              name: 'Tucson',
              modelYear: 2023,
              profileName: 'default.json',
            ),
          ],
        ),
      )..profiles['tucson'] = testProfileJson;
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

      expect(find.text('2 values your car can report'), findsOneWidget);
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
}
