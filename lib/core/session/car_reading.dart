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
/// one, it's [CarSilent], also when its bus fails as it switches off.
Future<CarReading> readCar(
  Elm327 elm, {
  required Set<String> keys,
  required SignalSet? profile,
  required int? modelYear,
  required Set<int> supportedPids,
}) async {
  try {
    final (:values, :unreported, :unanswered, :answered) = await readValues(
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
    // A request nothing answered says something only if the module asked
    // is awake: it answered something else, or the engine runs. Otherwise
    // it may only be asleep, as for a while after the car is switched off.
    final missing = {
      ...unreported,
      for (final MapEntry(:key, value: module) in unanswered.entries)
        if (carState == CarState.engineRunning || answered.contains(module))
          key: Unreported.noAnswer,
    };
    return values.isEmpty
        ? CarAwake(carState, unreported: missing)
        : CarAnswered(values, carState, unreported: missing);
  } on ElmException catch (e) {
    if (e.error == ElmError.unableToConnect) return const CarSilent();
    // The bus stopped mid-reading, as it does while the car switches off:
    // silent if the car doesn't answer now either. If it does, the bus
    // error was something else, and stays an error.
    if (e.error == ElmError.busError && await _stoppedAnswering(elm)) {
      return const CarSilent();
    }
    rethrow;
  }
}

/// Whether the car no longer answers, as after a bus error while it was
/// switched off: unable to connect, or its bus still in error.
Future<bool> _stoppedAnswering(Elm327 elm) async {
  try {
    await elm.checkCarAnswers();
    return false;
  } on ElmException catch (e) {
    return switch (e.error) {
      ElmError.unableToConnect || ElmError.busError => true,
      _ => throw e,
    };
  }
}
