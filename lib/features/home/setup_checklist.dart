import '../../core/settings/settings.dart';

/// Something Pitwall needs before it can run on its own.
enum SetupStep { vehicle, webhook, headUnit, permissions }

/// Where setup stands: each step, whether it's done, and a line about it.
class SetupChecklist {
  const SetupChecklist(this.items);

  factory SetupChecklist.from({
    required AppSettings settings,
    required bool hasWebhook,
    required int missingPermissions,
  }) {
    final vehicles = settings.vehicles;
    final headUnit = settings.wakeTrigger == WakeTrigger.carBluetooth
        ? settings.headUnitName
        : null;
    return SetupChecklist([
      (
        step: SetupStep.vehicle,
        done: vehicles.isNotEmpty,
        detail: switch (vehicles) {
          [] => 'Your car and the OBD-II adapter in it',
          [final only] => only.name,
          _ => '${vehicles.length} vehicles',
        },
      ),
      (
        step: SetupStep.webhook,
        done: hasWebhook,
        detail: hasWebhook
            ? 'Readings go to your webhook'
            : 'Where readings go',
      ),
      (
        step: SetupStep.headUnit,
        done: headUnit != null,
        detail: headUnit == null
            ? 'So trips start on their own'
            : 'Trips start when $headUnit connects',
      ),
      (
        step: SetupStep.permissions,
        done: missingPermissions == 0,
        detail: missingPermissions == 0
            ? 'All allowed'
            : '$missingPermissions to allow',
      ),
    ]);
  }

  final List<({SetupStep step, bool done, String detail})> items;

  bool get complete => items.every((item) => item.done);

  int get doneCount => items.where((item) => item.done).length;
}
