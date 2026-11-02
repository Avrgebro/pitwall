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
    final missingStart = vehicles.where((v) => !v.hasTripStart).toList();
    return SetupChecklist([
      (
        step: SetupStep.vehicle,
        done: vehicles.isNotEmpty,
        detail: switch (vehicles) {
          [] => 'Your car and the OBD-II adapter in it',
          [final only] => only.name,
          _ => '${vehicles.length} vehicles',
        },
        vehicleId: null,
      ),
      (
        step: SetupStep.webhook,
        done: hasWebhook,
        detail: hasWebhook
            ? 'Readings go to your webhook'
            : 'Where readings go',
        vehicleId: null,
      ),
      (
        step: SetupStep.headUnit,
        done: vehicles.isNotEmpty && missingStart.isEmpty,
        detail: switch ((vehicles, missingStart)) {
          ([], _) => 'So trips start on their own',
          ([final only], []) =>
            'Trips start when ${only.headUnitName} connects',
          (_, []) => 'Every vehicle has one',
          (_, [final one]) => '${one.name} needs one',
          (_, final several) => '${several.length} vehicles need one',
        },
        // The one vehicle to fix, if there's just one.
        vehicleId: missingStart.length == 1 ? missingStart.single.id : null,
      ),
      (
        step: SetupStep.permissions,
        done: missingPermissions == 0,
        detail: missingPermissions == 0
            ? 'All allowed'
            : '$missingPermissions to allow',
        vehicleId: null,
      ),
    ]);
  }

  final List<({SetupStep step, bool done, String detail, String? vehicleId})>
  items;

  bool get complete => items.every((item) => item.done);

  int get doneCount => items.where((item) => item.done).length;
}
