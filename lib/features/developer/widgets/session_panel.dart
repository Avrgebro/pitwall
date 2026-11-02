import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/session/car_state.dart';
import '../../../core/vehicles/vehicle.dart';
import '../../../state/infrastructure.dart';
import '../../../state/session_state.dart';
import '../../../state/trip_state.dart';
import '../../../ui/ui.dart';

/// Connects to a vehicle's adapter by hand, or simulates an auto-start: a
/// background trip, as if the car's head unit had connected.
class SessionPanel extends ConsumerWidget {
  const SessionPanel({super.key, required this.vehicle, this.onChooseVehicle});

  /// The vehicle to connect to, or null if there's none with an adapter.
  final Vehicle? vehicle;

  /// Picks another vehicle; null when there's no choice, or while a session
  /// or trip is in progress.
  final VoidCallback? onChooseVehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final trip = ref.watch(tripProvider);
    final tripController = ref.read(tripProvider.notifier);
    final controller = ref.read(sessionProvider.notifier);
    final vehicle = this.vehicle;
    // Assumed on until Android says otherwise, so nothing flashes.
    final bluetoothOn = ref.watch(bluetoothOnProvider).value ?? true;
    final canConnect = vehicle != null && bluetoothOn;

    final (chip, detail) = switch (session.phase) {
      SessionPhase.connected => (
        const StatusChip(
          label: 'Connected',
          tone: StatusTone.active,
          emphasis: ChipEmphasis.filled,
          dot: true,
        ),
        [
          ?session.adapterVersion,
          _carState(session.carState),
          '${session.supportedPids.length} standard values',
        ].join(' · '),
      ),
      SessionPhase.connecting => (
        const StatusChip(
          label: 'Connecting',
          tone: StatusTone.active,
          icon: Symbols.bluetooth_searching_rounded,
        ),
        'Talking to ${vehicle?.adapterName ?? 'the adapter'}…',
      ),
      SessionPhase.idle => (
        const StatusChip(
          label: 'Not connected',
          emphasis: ChipEmphasis.outlined,
          icon: Symbols.bluetooth_disabled_rounded,
        ),
        switch (vehicle) {
          null => 'Add a vehicle with an adapter first.',
          _ when !bluetoothOn => 'Bluetooth is off. Turn it on to connect.',
          final vehicle =>
            _problem(session.problem) ??
                'Connect to ${vehicle.adapterName} to read by hand.',
        },
      ),
    };

    return ContentCard(
      padding: Insets.card,
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
              if (session.busy)
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
            children: switch (session.phase) {
              // The trip drives the session; manual controls would fight it.
              _ when trip.isActive => [
                OutlinedButton.icon(
                  onPressed: trip.phase == TripPhase.ending
                      ? null
                      : tripController.stop,
                  icon: const Icon(Symbols.stop_circle_rounded),
                  label: const Text('Stop trip'),
                ),
              ],
              SessionPhase.connected => [
                FilledButton.icon(
                  onPressed: session.busy ? null : controller.readAndSend,
                  icon: const Icon(Symbols.send_rounded),
                  label: const Text('Read and send'),
                ),
                OutlinedButton(
                  onPressed: controller.disconnect,
                  child: const Text('Disconnect'),
                ),
              ],
              SessionPhase.connecting => const [],
              SessionPhase.idle => [
                FilledButton.icon(
                  onPressed: canConnect
                      ? () => controller.connect(vehicle)
                      : null,
                  icon: const Icon(Symbols.bluetooth_connected_rounded),
                  label: const Text('Connect'),
                ),
                OutlinedButton.icon(
                  onPressed: canConnect
                      ? () =>
                            tripController.startManually(vehicleId: vehicle.id)
                      : null,
                  icon: const Icon(Symbols.play_circle_rounded),
                  label: const Text('Simulate auto-start'),
                ),
              ],
            },
          ),
          if (session.phase == SessionPhase.idle &&
              !trip.isActive &&
              canConnect) ...[
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

  static String? _tripLine(TripState trip) => switch (trip.phase) {
    TripPhase.connecting => 'Background trip: looking for the adapter',
    TripPhase.running => 'Background trip: running',
    TripPhase.ending => 'Background trip: sending the last reading',
    TripPhase.idle => switch (trip.lastEnd) {
      null => null,
      final end => 'Last trip ended: ${_tripEnd(end)}',
    },
  };

  static String _tripEnd(TripEnd end) => switch (end) {
    TripEnd.stopped => 'stopped',
    TripEnd.noVehicle => 'no vehicle has an adapter',
    TripEnd.permissionMissing => 'Bluetooth permission missing',
    TripEnd.adapterNotFound => 'the adapter didn\'t answer',
    TripEnd.carOff => 'the car stopped answering',
    TripEnd.adapterLost => 'the adapter dropped',
  };

  static String _carState(CarState state) => switch (state) {
    CarState.engineRunning => 'engine running',
    CarState.ignitionOn => 'ignition on',
    CarState.off => 'car not answering',
    CarState.unknown => 'checking the car',
  };

  static String? _problem(SessionProblem? problem) => switch (problem) {
    SessionProblem.permissionDenied =>
      'Pitwall needs the Bluetooth permission to connect.',
    SessionProblem.connectFailed =>
      'Couldn\'t reach the adapter. Is it plugged in and the ignition on?',
    SessionProblem.disconnected => 'The adapter disconnected.',
    SessionProblem.adapterError =>
      'The adapter stopped answering. Connect again.',
    null => null,
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
              if (vehicle.adapterName case final adapter?)
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
