import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/session/car_state.dart';
import '../../../core/vehicles/vehicle.dart';
import '../../../state/session_state.dart';
import '../../../state/trip_state.dart';
import '../../../ui/ui.dart';

/// Connects to a vehicle's adapter by hand, or starts a background trip as
/// if the car's head unit had connected.
class SessionPanel extends ConsumerWidget {
  const SessionPanel({super.key, required this.vehicle});

  /// The vehicle to connect to, or null if there's none with an adapter.
  final Vehicle? vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final trip = ref.watch(tripProvider);
    final tripController = ref.read(tripProvider.notifier);
    final controller = ref.read(sessionProvider.notifier);
    final vehicle = this.vehicle;

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
        _problem(session.problem) ??
            (vehicle == null
                ? 'Add a vehicle with an adapter first.'
                : 'Connect to ${vehicle.adapterName} to read by hand.'),
      ),
    };

    return ContentCard(
      padding: Insets.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                  onPressed: vehicle == null
                      ? null
                      : () => controller.connect(vehicle),
                  icon: const Icon(Symbols.bluetooth_connected_rounded),
                  label: const Text('Connect'),
                ),
                OutlinedButton.icon(
                  onPressed: vehicle == null
                      ? null
                      : tripController.startManually,
                  icon: const Icon(Symbols.play_circle_rounded),
                  label: const Text('Start trip'),
                ),
              ],
            },
          ),
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
