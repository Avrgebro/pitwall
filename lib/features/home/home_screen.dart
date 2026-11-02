import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/readings/readings.dart';
import '../../state/focus_state.dart';
import '../../state/infrastructure.dart';
import '../../state/last_values_state.dart';
import '../../state/permissions_state.dart';
import '../../state/session_state.dart';
import '../../state/trip_state.dart';
import '../../state/settings_state.dart';
import '../../state/webhook_state.dart';
import '../../ui/ui.dart';
import '../common/widgets/vehicle_picker_sheet.dart';
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
    final webhook = ref.watch(webhookProvider).value;
    if (settings == null || webhook == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final session = ref.watch(sessionProvider);
    final vehicle = ref.watch(focusedVehicleProvider);

    // Before the first vehicle, Home walks through setup. After, problems
    // show where they belong: the vehicle, the delivery card, Settings.
    if (vehicle == null) {
      return AppPage(
        title: 'Pitwall',
        children: [
          SetupChecklistCard(
            checklist: SetupChecklist.from(
              settings: settings,
              hasWebhook: webhook.hasUrl,
              missingPermissions: ref.watch(missingPermissionsProvider),
            ),
          ),
        ],
      );
    }

    final profile = ref.watch(vehicleProfileProvider(vehicle.id)).value;
    final model = HomeViewModel.build(
      vehicle: vehicle,
      settings: settings,
      session: session,
      trip: ref.watch(tripProvider),
      delivery: ref.watch(deliveryStatusProvider),
      hasWebhook: webhook.hasUrl,
      options: valueOptions(profile, vehicle.modelYear),
      lastValues: ref.watch(lastValuesProvider).value?.of(vehicle.id) ?? {},
      now: ref.watch(nowProvider),
    );
    final delivery = DeliveryStatusCard(
      model: model.delivery,
      onOpenSettings: () => context.go(Routes.settings),
      onSetWebhook: () => context.push(Routes.webhookSettings),
      onRetry: () => ref.read(deliveryStatusProvider.notifier).retryNow(),
    );

    return AppPage(
      title: 'Pitwall',
      children: [
        VehicleHeroCard(
          model: model.hero,
          // With more than one vehicle, its name switches between them.
          onSwitch: settings.vehicles.length > 1
              ? () => VehiclePickerSheet.show(context, title: 'Show on Home')
              : null,
        ),
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
