import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/readings/readings.dart';
import '../../state/infrastructure.dart';
import '../../state/permissions_state.dart';
import '../../state/session_state.dart';
import '../../state/settings_state.dart';
import '../../state/webhook_state.dart';
import '../../ui/ui.dart';
import 'home_view_model.dart';
import 'setup_checklist.dart';
import 'widgets/delivery_status_card.dart';
import 'widgets/setup_checklist_card.dart';
import 'widgets/vehicle_hero_card.dart';

/// Status at a glance: what's left to set up, the vehicle seen most
/// recently (or connected now), the last values sent, and delivery health.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider).value;
    final webhook = ref.watch(webhookConfigProvider).value;
    if (settings == null || webhook == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final checklist = SetupChecklist.from(
      settings: settings,
      hasWebhook: webhook.hasUrl,
      missingPermissions: ref.watch(missingPermissionsProvider),
    );
    final setup = checklist.complete
        ? null
        : SetupChecklistCard(checklist: checklist);
    final session = ref.watch(sessionProvider);
    final vehicle =
        (session.vehicleId == null
            ? null
            : settings.vehicleById(session.vehicleId!)) ??
        settings.mostRecentVehicle;

    if (vehicle == null) {
      // Adding a vehicle is one of the steps, so setup is never complete.
      return AppPage(title: 'Pitwall', children: [?setup]);
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
        if (setup != null) ...[setup, const SizedBox(height: Insets.xl)],
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
