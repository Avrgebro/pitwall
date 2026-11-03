import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/readings/readings.dart';
import '../../../core/vehicles/vehicle.dart';
import '../../../state/settings_state.dart';
import '../../../ui/ui.dart';

/// A page about one vehicle: built with the vehicle and its values while
/// it exists. Once it's gone, say deleted while the page was open
/// underneath, the page says so instead.
class VehiclePage extends ConsumerWidget {
  const VehiclePage({
    super.key,
    required this.vehicleId,
    required this.title,
    required this.builder,
  });

  final String vehicleId;

  /// The page's title while loading, or once the vehicle is gone.
  final String title;

  final Widget Function(
    BuildContext context,
    Vehicle vehicle,
    VehicleValues values,
  )
  builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(appSettingsProvider).hasValue) {
      return AppPage.loading(title: title);
    }
    final vehicle = ref.watch(vehicleProvider(vehicleId));
    final values = ref.watch(vehicleValuesProvider(vehicleId));
    if (vehicle == null || values == null) {
      return AppPage(
        title: title,
        children: const [
          InfoNote(text: TextSpan(text: 'This vehicle was removed.')),
        ],
      );
    }
    return builder(context, vehicle, values);
  }
}
