import 'package:material_ui/material_ui.dart';

import '../../../core/format/formatters.dart';
import '../../../core/vehicles/vehicle.dart';
import '../../../ui/ui.dart';
import '../../common/vehicle_text.dart';

enum VehicleBadge { none, connected, onHome }

/// A vehicle in the list: its name, and one line for its state, or for
/// what it needs when something's missing. Setup details live on its page.
class VehicleRow extends StatelessWidget {
  const VehicleRow({
    super.key,
    required this.vehicle,
    required this.needs,
    required this.now,
    required this.onTap,
    this.badge = VehicleBadge.none,
  });

  final Vehicle vehicle;

  /// What it lacks before it works on its own; see [Vehicle.needs].
  final List<VehicleNeed> needs;
  final DateTime now;
  final VehicleBadge badge;
  final VoidCallback onTap;

  /// What the vehicle needs before it works on its own, if anything.
  String? get _problem => switch (needs) {
    [final need, ...] => need.label,
    [] => null,
  };

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    final lastSeen = vehicle.lastSeen;
    final status = switch (badge) {
      VehicleBadge.connected => 'Connected now',
      _ when lastSeen != null => 'Last seen ${Formatters.ago(lastSeen, now)}',
      _ => 'Never connected',
    };
    final chip = switch (badge) {
      VehicleBadge.connected => const StatusChip(
        label: 'Connected',
        tone: StatusTone.active,
        emphasis: Emphasis.filled,
        dot: true,
        dense: true,
      ),
      // Outlined: a neutral fill would vanish into the glass row.
      VehicleBadge.onHome => const StatusChip(
        label: 'On Home',
        emphasis: Emphasis.outlined,
        dense: true,
      ),
      VehicleBadge.none => null,
    };
    return AppRow(
      title: vehicle.name,
      // A problem replaces the status, so a car that needs something reads
      // differently at a glance.
      subtitle: Text(problem ?? status),
      subtitleTone: problem == null ? null : StatusTone.error,
      trailing: chip,
      opensPage: true,
      onTap: onTap,
    );
  }
}
