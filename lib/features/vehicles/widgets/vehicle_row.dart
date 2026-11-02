import 'package:material_ui/material_ui.dart';

import '../../../core/vehicles/vehicle.dart';
import '../../../ui/ui.dart';
import '../../common/trip_start_text.dart';

enum VehicleBadge { none, connected, onHome }

/// A vehicle in the list: its name, and one line for its state, or for
/// what it needs when something's missing. Setup details live on its page.
class VehicleRow extends StatelessWidget {
  const VehicleRow({
    super.key,
    required this.vehicle,
    required this.now,
    required this.onTap,
    this.badge = VehicleBadge.none,
  });

  final Vehicle vehicle;
  final DateTime now;
  final VehicleBadge badge;
  final VoidCallback onTap;

  /// What the vehicle needs before it works on its own, if anything.
  static String? _problem(Vehicle vehicle) =>
      switch (vehicle.needs.firstOrNull) {
        null => null,
        VehicleNeed.adapter => 'Choose its adapter',
        VehicleNeed.headUnit || VehicleNeed.supportedTripStart =>
          '${TripStartText.summary(vehicle).text} for trip start',
      };

  @override
  Widget build(BuildContext context) {
    final problem = _problem(vehicle);
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
        emphasis: ChipEmphasis.filled,
        dot: true,
        dense: true,
      ),
      // Outlined: a neutral fill would vanish into the glass row.
      VehicleBadge.onHome => const StatusChip(
        label: 'On Home',
        emphasis: ChipEmphasis.outlined,
        dense: true,
      ),
      VehicleBadge.none => null,
    };
    final accent = Theme.of(context).colorScheme.primary;
    return RowLayout(
      title: vehicle.name,
      // A problem replaces the status, so a car that needs something reads
      // differently at a glance.
      subtitle: Text(
        problem ?? status,
        style: problem == null
            ? null
            : TextStyle(color: context.tone(StatusTone.error).accent),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?chip,
          if (chip != null) const SizedBox(width: Insets.s),
          Icon(Icons.chevron_right, color: accent),
        ],
      ),
      onTap: onTap,
    );
  }
}
