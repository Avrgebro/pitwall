import '../readings/metric.dart';

enum CarState {
  /// Not known yet: no connection, or nothing read.
  unknown,

  /// The adapter answered but the car didn't.
  off,

  /// The car answers, but the engine isn't running.
  ignitionOn,

  /// The engine is running.
  engineRunning,
}

/// Above this, the alternator is charging, so the engine is running.
const chargingVoltage = 13.2;

/// Works out the car's state from values read while it answers.
CarState carStateFrom(Map<String, num> values) {
  final rpm = values[Metrics.engineSpeed.key];
  final voltage = values[Metrics.batteryVoltage.key];
  if ((rpm != null && rpm > 0) ||
      (voltage != null && voltage >= chargingVoltage)) {
    return CarState.engineRunning;
  }
  return CarState.ignitionOn;
}
