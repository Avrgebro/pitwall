import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/session/car_state.dart';
import '../../../core/trips/trip_target.dart';
import '../../../core/vehicles/vehicle.dart';
import '../../../core/platform/permission_gateway.dart';
import '../../../state/infrastructure.dart';
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
    final session = ref.watch(sessionProvider);
    final trip = ref.watch(tripProvider);
    final tripController = ref.read(tripProvider.notifier);
    final controller = ref.read(sessionProvider.notifier);
    final readings = ref.read(readingKeeperProvider);
    final vehicle = this.vehicle;
    // Assumed on until Android says otherwise, so nothing flashes.
    final bluetoothOn = ref.watch(bluetoothOnProvider).value ?? true;
    final needsAdapter = vehicle?.needs.contains(VehicleNeed.adapter) ?? false;
    final canConnect = vehicle != null && !needsAdapter && bluetoothOn;

    final (chip, detail) = switch (session) {
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
      SessionIdle(:final problem) => (
        const StatusChip(
          label: 'Not connected',
          emphasis: Emphasis.outlined,
          icon: Symbols.bluetooth_disabled_rounded,
        ),
        switch (vehicle) {
          null => 'Add a vehicle first.',
          _ when needsAdapter => '${VehicleNeed.adapter.label} first.',
          _ when !bluetoothOn => 'Bluetooth is off. Turn it on to connect.',
          final vehicle =>
            problem?.label ??
                'Connect to ${vehicle.adapter?.name} to read by hand.',
        },
      ),
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
            children: switch (session) {
              // The trip drives the session; manual controls would fight it.
              _ when trip.isActive => [
                OutlinedButton.icon(
                  onPressed: trip is TripEnding ? null : tripController.stop,
                  icon: const Icon(Symbols.stop_circle_rounded),
                  label: const Text('Stop trip'),
                ),
              ],
              SessionConnected(:final busy) => [
                FilledButton.icon(
                  onPressed: busy ? null : readings.readAndKeep,
                  icon: const Icon(Symbols.send_rounded),
                  label: const Text('Read and send'),
                ),
                OutlinedButton(
                  onPressed: controller.disconnect,
                  child: const Text('Disconnect'),
                ),
              ],
              SessionConnecting() => const [],
              SessionIdle() => [
                FilledButton.icon(
                  onPressed: canConnect
                      ? () async {
                          // Asked here, where there's a screen to ask on;
                          // connecting only checks.
                          await ref
                              .read(permissionsProvider.notifier)
                              .request(AppPermission.bluetooth);
                          await controller.connect(vehicle);
                        }
                      : null,
                  icon: const Icon(Symbols.bluetooth_connected_rounded),
                  label: const Text('Connect'),
                ),
                OutlinedButton.icon(
                  onPressed: canConnect
                      ? () => tripController.startManually(
                          VehicleTarget(vehicle.id),
                        )
                      : null,
                  icon: const Icon(Symbols.play_circle_rounded),
                  label: const Text('Simulate auto-start'),
                ),
              ],
            },
          ),
          if (session is SessionIdle && !trip.isActive && canConnect) ...[
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
