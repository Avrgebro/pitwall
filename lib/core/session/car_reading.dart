import '../obd/elm327.dart';
import '../profiles/signal_set.dart';
import '../readings/metric.dart';
import '../readings/readings.dart';
import '../readings/unreported.dart';
import 'car_state.dart';

/// What one read of the car found.
sealed class CarReading {
  const CarReading();
}

/// The car answered, with [values] to send: what it, and the adapter,
/// reported. Never empty; see [CarAwake]. Chosen values it didn't report
/// are in [unreported], with why.
final class CarAnswered extends CarReading {
  const CarAnswered(this.values, this.carState, {this.unreported = const {}})
    : assert(values.length > 0, 'Nothing to send is CarAwake');

  final Map<String, double> values;
  final CarState carState;
  final Map<String, Unreported> unreported;
}

/// The car answered, but with nothing to send: none of the chosen values,
/// each in [unreported] with why, or it was only asked whether it answers.
final class CarAwake extends CarReading {
  const CarAwake(this.carState, {this.unreported = const {}});

  final CarState carState;
  final Map<String, Unreported> unreported;
}

/// The adapter answered but the car didn't: the ignition is off.
final class CarSilent extends CarReading {
  const CarSilent();
}

/// Reads the values in [keys] from the car through [elm], with [profile]'s
/// requests for [modelYear], and works out the car's state.
///
/// Throws [ElmException] for adapter failures; the car not answering isn't
/// one, it's [CarSilent].
Future<CarReading> readCar(
  Elm327 elm, {
  required Set<String> keys,
  required SignalSet? profile,
  required int? modelYear,
  required Set<int> supportedPids,
}) async {
  try {
    final (:values, :unreported) = await readValues(
      elm,
      keys: keys,
      supportedPids: supportedPids,
      profile: profile,
      modelYear: modelYear,
    );
    // Values the adapter measures itself come back with the car switched
    // off too; without any from the car, make sure it still answers.
    if (values.keys.every((key) => key == Metrics.batteryVoltage.key)) {
      await elm.checkCarAnswers();
    }
    // The engine's state needs the battery voltage, sent or not.
    final voltage =
        values[Metrics.batteryVoltage.key] ?? await elm.readBatteryVoltage();
    final carState = carStateFrom({
      ...values,
      Metrics.batteryVoltage.key: ?voltage,
    });
    // A car that reported nothing of its own, as for a while after it's
    // switched off, says nothing about any one value by not answering.
    // Only a reply it did send can be short of one, or mark it unavailable.
    final fromCar = values.keys.any((key) => key != Metrics.batteryVoltage.key);
    final missing = fromCar
        ? unreported
        : {
            for (final MapEntry(:key, value: why) in unreported.entries)
              if (why == Unreported.notInReply || why == Unreported.unavailable)
                key: why,
          };
    return values.isEmpty
        ? CarAwake(carState, unreported: missing)
        : CarAnswered(values, carState, unreported: missing);
  } on ElmException catch (e) {
    if (e.error != ElmError.unableToConnect) rethrow;
    return const CarSilent();
  }
}
