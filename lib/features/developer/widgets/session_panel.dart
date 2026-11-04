import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/platform/permission_gateway.dart';
import '../../../core/session/car_state.dart';
import '../../../core/trips/trip_target.dart';
import '../../../core/vehicles/vehicle.dart';
import '../../../state/manual_controls.dart';
import '../../../state/permissions_state.dart';
import '../../../state/reading_keeper.dart';
import '../../../state/session_state.dart';
import '../../../state/trip_state.dart';
import '../../../ui/ui.dart';
import '../../common/session_text.dart';
import '../../common/vehicle_text.dart';

/// Connects to a vehicle's adapter by hand, or simulates an auto-start: a
/// background trip, as if the car's head unit had connected.
class SessionPanel extends ConsumerWidget {
  const SessionPanel({super.key, required this.vehicle, this.onChooseVehicle});

  /// The vehicle to connect to, or null if there's none.
  final Vehicle? vehicle;

  /// Picks another vehicle; null with only one. While one is live, the
  /// picker keeps the others unavailable.
  final VoidCallback? onChooseVehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicle = this.vehicle;
    final session = ref.watch(sessionProvider);
    final trip = ref.watch(tripProvider);
    final controls = ref.watch(manualControlsProvider(vehicle?.id));
    final tripController = ref.read(tripProvider.notifier);
    final controller = ref.read(sessionProvider.notifier);
    final readings = ref.read(readingKeeperProvider);

    final (chip, sessionDetail) = switch (session) {
      SessionConnected(
        :final adapterVersion,
        :final carState,
        :final supportedPids,
      ) =>
        (
          const StatusChip(
            label: 'Connected',
            tone: StatusTone.active,
            emphasis: Emphasis.filled,
            dot: true,
          ),
          [
            ?adapterVersion,
            _carState(carState),
            '${supportedPids.length} standard values',
          ].join(', '),
        ),
      SessionConnecting() => (
        const StatusChip(
          label: 'Connecting',
          tone: StatusTone.active,
          icon: Symbols.bluetooth_searching_rounded,
        ),
        'Talking to ${vehicle?.adapter?.name ?? 'the adapter'}…',
      ),
      // Idle under a trip: between its connections.
      SessionIdle(:final problem) => (
        const StatusChip(
          label: 'Not connected',
          emphasis: Emphasis.outlined,
          icon: Symbols.bluetooth_disabled_rounded,
        ),
        problem?.label ?? 'The background trip uses the adapter.',
      ),
    };
    final detail = switch (controls) {
      BlockedControls(blocker: IdleBlocker.noVehicle) => 'Add a vehicle first.',
      BlockedControls(blocker: IdleBlocker.needsAdapter) =>
        '${VehicleNeed.adapter.label} first.',
      BlockedControls(blocker: IdleBlocker.bluetoothOff) =>
        'Bluetooth is off. Turn it on to connect.',
      IdleControls(:final adapter, :final problem) =>
        problem?.label ?? 'Connect to ${adapter.name} to read by hand.',
      TripControls() || SessionControls() || WaitingControls() => sessionDetail,
    };
    // Connecting and simulating need a vehicle ready to connect to.
    final ready = switch (controls) {
      final IdleControls ready => ready,
      _ => null,
    };

    return ContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (vehicle != null) ...[
            _VehicleLine(vehicle: vehicle, onChoose: onChooseVehicle),
            const SizedBox(height: Insets.m),
          ],
          Row(
            children: [
              chip,
              const Spacer(),
              if (session case SessionConnected(busy: true))
                const SizedBox.square(
                  dimension: Sizes.iconSmall,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: Insets.s),
          Text(detail, style: Theme.of(context).textTheme.bodyMedium),
          if (_tripLine(trip) case final line?) ...[
            const SizedBox(height: Insets.xs),
            Text(line, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: Insets.m),
          Wrap(
            spacing: Insets.s,
            runSpacing: Insets.s,
            children: switch (controls) {
              TripControls(:final canStop) => [
                OutlinedButton.icon(
                  onPressed: canStop ? tripController.stop : null,
                  icon: const Icon(Symbols.stop_circle_rounded),
                  label: const Text('Stop trip'),
                ),
              ],
              SessionControls(:final canRead) => [
                FilledButton.icon(
                  onPressed: canRead ? readings.readAndKeep : null,
                  icon: const Icon(Symbols.send_rounded),
                  label: const Text('Read and send'),
                ),
                OutlinedButton(
                  onPressed: controller.disconnect,
                  child: const Text('Disconnect'),
                ),
              ],
              WaitingControls() => const [],
              IdleControls() || BlockedControls() => [
                FilledButton.icon(
                  onPressed: ready == null
                      ? null
                      : () async {
                          // Asked here, where there's a screen to ask on;
                          // connecting only checks.
                          await ref
                              .read(permissionsProvider.notifier)
                              .request(AppPermission.bluetooth);
                          await controller.connect(ready.vehicle);
                        },
                  icon: const Icon(Symbols.bluetooth_connected_rounded),
                  label: const Text('Connect'),
                ),
                OutlinedButton.icon(
                  onPressed: ready == null
                      ? null
                      : () => tripController.startManually(
                          VehicleTarget(ready.vehicle.id),
                        ),
                  icon: const Icon(Symbols.play_circle_rounded),
                  label: const Text('Simulate auto-start'),
                ),
              ],
            },
          ),
          if (ready != null) ...[
            const SizedBox(height: Insets.m),
            Text(
              'Connect opens a manual session. Simulate auto-start runs the '
              'automatic flow, as if the car\'s Bluetooth connected. Either '
              'way the adapter must be within reach, usually in the car with '
              'the ignition on.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String? _tripLine(TripState trip) => switch (trip) {
    TripConnecting() => 'Background trip: looking for the adapter',
    TripRunning() => 'Background trip: running',
    TripEnding() => 'Background trip: sending the last reading',
    TripIdle(lastEnd: null) => null,
    TripIdle(:final lastEnd?) => 'Last trip ended: ${lastEnd.label}',
  };

  static String _carState(CarState state) => switch (state) {
    CarState.engineRunning => 'engine running',
    CarState.ignitionOn => 'ignition on',
    CarState.off => 'car not answering',
    CarState.unknown => 'checking the car',
  };
}

/// The vehicle the session is for, with its adapter; a picker when there's
/// a choice.
class _VehicleLine extends StatelessWidget {
  const _VehicleLine({required this.vehicle, required this.onChoose});

  final Vehicle vehicle;
  final VoidCallback? onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onChoose = this.onChoose;
    final line = Row(
      children: [
        Icon(Symbols.directions_car_rounded, color: scheme.primary),
        const SizedBox(width: Insets.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(vehicle.name, style: theme.textTheme.titleMedium),
              if (vehicle.adapter?.name case final adapter?)
                Text(
                  adapter,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        if (onChoose != null) const Icon(Icons.arrow_drop_down),
      ],
    );
    if (onChoose == null) return line;
    // Its own node, so screen readers don't fold the rest of the card into
    // this button.
    return Semantics(
      container: true,
      button: true,
      hint: 'Choose the vehicle',
      child: InkWell(
        onTap: onChoose,
        borderRadius: Corners.mediumRadius,
        child: line,
      ),
    );
  }
}
