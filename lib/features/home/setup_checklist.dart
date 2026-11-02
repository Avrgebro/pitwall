import '../../core/settings/settings.dart';

/// Something Pitwall needs before it can run on its own.
enum SetupStep { vehicle, webhook, permissions }

/// Where setup stands before the first vehicle: each step, whether it's
/// done, and a line about it. Once there's a vehicle, problems show where
/// they belong instead: on the vehicle, the delivery card, or Settings.
class SetupChecklist {
  const SetupChecklist(this.items);

  factory SetupChecklist.from({
    required AppSettings settings,
    required bool hasWebhook,
    required int missingPermissions,
  }) => SetupChecklist([
    (
      step: SetupStep.vehicle,
      done: settings.vehicles.isNotEmpty,
      detail: 'Your car and the OBD-II adapter in it',
    ),
    (
      step: SetupStep.webhook,
      done: hasWebhook,
      detail: hasWebhook ? 'Readings go to your webhook' : 'Where readings go',
    ),
    (
      step: SetupStep.permissions,
      done: missingPermissions == 0,
      detail: missingPermissions == 0
          ? 'All allowed'
          : '$missingPermissions to allow',
    ),
  ]);

  final List<({SetupStep step, bool done, String detail})> items;

  bool get complete => items.every((item) => item.done);

  int get doneCount => items.where((item) => item.done).length;
}
