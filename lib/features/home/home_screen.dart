import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/routes.dart';
import '../../core/readings/readings.dart';
import '../../state/infrastructure.dart';
import '../../state/session_state.dart';
import '../../state/settings_state.dart';
import '../../state/webhook_state.dart';
import '../../ui/ui.dart';
import 'home_view_model.dart';
import 'widgets/delivery_status_card.dart';
import 'widgets/vehicle_hero_card.dart';

/// Status at a glance: the vehicle seen most recently (or connected now),
/// the last values sent, and delivery health.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider).value;
    if (settings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final session = ref.watch(sessionProvider);
    final vehicle =
        (session.vehicleId == null
            ? null
            : settings.vehicleById(session.vehicleId!)) ??
        settings.mostRecentVehicle;

    if (vehicle == null) {
      return AppPage(
        title: 'Pitwall',
        children: [
          const SizedBox(height: Insets.xxl * 2),
          EmptyState(
            icon: Symbols.directions_car_rounded,
            title: 'No vehicles yet',
            message: 'Add your car and the OBD-II adapter plugged into it.',
            actionLabel: 'Add vehicle',
            actionIcon: Symbols.add_rounded,
            onAction: () => context.push(Routes.addVehicle),
          ),
        ],
      );
    }

    final profile = ref.watch(vehicleProfileProvider(vehicle.id)).value;
    final model = HomeViewModel.build(
      vehicle: vehicle,
      settings: settings,
      session: session,
      delivery: ref.watch(deliveryStatusProvider),
      options: valueOptions(profile, vehicle.modelYear),
      now: ref.watch(nowProvider),
    );
    final delivery = DeliveryStatusCard(
      model: model.delivery,
      onOpenSettings: () => context.go(Routes.settings),
      onRetry: () => ref.read(deliveryStatusProvider.notifier).retryNow(),
    );

    return AppPage(
      title: 'Pitwall',
      children: [
        VehicleHeroCard(model: model.hero),
        if (model.delivery.isProblem) ...[
          const SizedBox(height: Insets.l),
          delivery,
        ],
        if (model.values case final values?) ...[
          SectionHeader(values.title, trailing: values.meta),
          ValueGrid(values: values.tiles),
        ],
        if (!model.delivery.isProblem) ...[
          const SizedBox(height: Insets.l),
          delivery,
        ],
      ],
    );
  }
}
