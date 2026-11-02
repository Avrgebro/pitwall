import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/routes.dart';
import '../../../ui/ui.dart';
import '../setup_checklist.dart';

/// What's left to set up, each item opening the page that fixes it. Shown
/// on Home until everything is done.
class SetupChecklistCard extends StatelessWidget {
  const SetupChecklistCard({super.key, required this.checklist});

  final SetupChecklist checklist;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionHeader(
        'Finish setting up',
        trailing: '${checklist.doneCount} of ${checklist.items.length} done',
        padding: const EdgeInsets.fromLTRB(Insets.xs, 0, Insets.xs, Insets.s),
      ),
      RowGroup(
        children: [
          for (final item in checklist.items)
            ChecklistRow(
              title: _title(item.step),
              subtitle: item.detail,
              done: item.done,
              fixLabel: _action(item.step),
              onFix: () => context.push(_route(item.step, item.vehicleId)),
            ),
        ],
      ),
    ],
  );

  static String _title(SetupStep step) => switch (step) {
    SetupStep.vehicle => 'Add a vehicle',
    SetupStep.webhook => 'Set the webhook',
    SetupStep.headUnit => 'Choose your car\'s Bluetooth',
    SetupStep.permissions => 'Allow background checks',
  };

  static String _action(SetupStep step) => switch (step) {
    SetupStep.vehicle => 'Add',
    SetupStep.webhook => 'Set',
    SetupStep.headUnit => 'Choose',
    SetupStep.permissions => 'Allow',
  };

  static String _route(SetupStep step, String? vehicleId) => switch (step) {
    SetupStep.vehicle => Routes.addVehicle,
    SetupStep.webhook => Routes.webhookSettings,
    SetupStep.headUnit => switch (vehicleId) {
      final id? => Routes.vehicleTripStart(id),
      // None yet: add one first. Several: pick from the list.
      null => Routes.vehicles,
    },
    SetupStep.permissions => Routes.backgroundChecks,
  };
}
