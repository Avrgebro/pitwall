import '../obd/elm327.dart';
import '../profiles/signal_set.dart';
import '../readings/readings.dart';
import '../vehicles/vehicle.dart';
import 'car_state.dart';

/// What one read of the car found.
sealed class CarReading {
  const CarReading();
}

/// The car answered. [values] are what it, and the adapter, reported:
/// possibly none of the chosen ones.
final class CarAnswered extends CarReading {
  const CarAnswered(this.values, this.carState);

  final Map<String, double> values;
  final CarState carState;
}

/// The adapter answered but the car didn't: the ignition is off.
final class CarSilent extends CarReading {
  const CarSilent();
}

/// Reads the values [vehicle] sends from the car through [elm], and works
/// out its state.
///
/// Throws [ElmException] for adapter failures; the car not answering isn't
/// one, it's [CarSilent].
Future<CarReading> readCar(
  Elm327 elm, {
  required Vehicle vehicle,
  required SignalSet? profile,
  required Set<int> supportedPids,
}) async {
  try {
    final values = await readValues(
      elm,
      keys: VehicleValues.of(vehicle, profile).sent,
      supportedPids: supportedPids,
      profile: profile,
      modelYear: vehicle.modelYear,
    );
    // Values the adapter measures itself come back with the car switched
    // off too; without any from the car, make sure it still answers.
    if (values.keys.every((key) => key == batteryVoltageKey)) {
      await elm.requestPid(0x00);
    }
    // The engine's state needs the battery voltage, sent or not.
    final voltage = values[batteryVoltageKey] ?? await elm.readBatteryVoltage();
    return CarAnswered(
      values,
      carStateFrom({...values, batteryVoltageKey: ?voltage}),
    );
  } on ElmException catch (e) {
    if (e.error != ElmError.unableToConnect) rethrow;
    return const CarSilent();
  }
}
