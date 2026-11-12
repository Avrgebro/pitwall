import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/obd/trouble_codes.dart';
import '../core/session/car_reading.dart';
import '../core/session/car_state.dart';
import '../core/vehicles/vehicle.dart';
import 'infrastructure.dart';
import 'last_values_state.dart';
import 'session_state.dart';

final readingKeeperProvider = Provider<ReadingKeeper>(ReadingKeeper.new);

/// Where readings go once read: into the delivery queue, which delivers on
/// its own, and into the last values Home shows. Used by trips and by
/// Developer tools, so a reading is kept the same way however it's made.
class ReadingKeeper {
  const ReadingKeeper(this._ref);

  final Ref _ref;

  /// Reads the car through the session and keeps what it answered. The
  /// adapter is free again before keeping starts, so a slow network or a
  /// failing disk can't hold it.
  Future<ReadOutcome> readAndKeep() async {
    final outcome = await _ref.read(sessionProvider.notifier).read();
    if (outcome case StepDone(
      value: VehicleReading(:final vehicle, troubleCodes: final codes?),
    )) {
      await _ref
          .read(lastValuesProvider.notifier)
          .recordTroubleCodes(vehicle.id, codes, DateTime.now());
    }
    switch (outcome) {
      case StepDone(
        value: VehicleReading(
          :final vehicle,
          reading: final CarAnswered reading,
          :final troubleCodes,
        ),
      ):
        await _keep(vehicle, reading, troubleCodes);
      case StepDone(
        value: VehicleReading(
          :final vehicle,
          reading: CarAwake(:final unreported),
        ),
      ):
        // Nothing to send, but what was asked for and didn't come is news.
        await _ref
            .read(lastValuesProvider.notifier)
            .noteUnreported(vehicle.id, unreported, DateTime.now());
      case StepDone() || StepRefused() || StepFailed():
        break;
    }
    return outcome;
  }

  /// Queues the reading that tells the receiver the car disconnected, and
  /// waits up to [wait] for it to be delivered. Undelivered, it stays
  /// queued and goes out with the next delivery.
  Future<void> close(Vehicle vehicle, {required Duration wait}) async {
    final sender = _ref.read(webhookSenderProvider);
    await sender.queue(
      device: vehicle.deviceId,
      values: const {},
      connected: false,
    );
    await sender.flush().timeout(wait, onTimeout: () {});
  }

  Future<void> _keep(
    Vehicle vehicle,
    CarAnswered reading,
    TroubleCodes? troubleCodes,
  ) async {
    final seq = await _ref
        .read(webhookSenderProvider)
        .queue(
          device: vehicle.deviceId,
          values: reading.values,
          connected: true,
          engineRunning: reading.carState == CarState.engineRunning,
          troubleCodes: troubleCodes,
        );
    await _ref
        .read(lastValuesProvider.notifier)
        .record(
          vehicle.id,
          reading.values,
          DateTime.now(),
          seq: seq,
          missing: reading.unreported,
        );
  }
}
