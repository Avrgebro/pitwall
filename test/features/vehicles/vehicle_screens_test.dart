import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pitwall/features/vehicles/values_to_send_screen.dart';
import 'package:pitwall/features/vehicles/vehicle_adapter_screen.dart';
import 'package:pitwall/features/vehicles/vehicle_detail_screen.dart';
import 'package:pitwall/features/vehicles/vehicle_name_screen.dart';
import 'package:pitwall/features/vehicles/vehicle_profile_screen.dart';
import 'package:pitwall/features/vehicles/vehicle_trip_start_screen.dart';
import 'package:pitwall/ui/ui.dart';

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
}
