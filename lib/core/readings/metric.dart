import 'package:flutter/foundation.dart';

/// How a metric's value reads on a tile.
enum MetricFormat {
  /// As a number with its unit.
  number,

  /// Seconds, as a duration ("24 min"); the payload keeps seconds.
  duration,
}

/// What a payload key means: what it's called, its unit, and where and how
/// it's shown. The standard ones are in [Metrics]; each profile signal is
/// one of its own.
@immutable
class Metric {
  const Metric({
    required this.key,
    required this.name,
    required this.unit,
    this.shortName,
    this.rank = unranked,
    this.format = MetricFormat.number,
  });

  /// Where metrics with no place of their own go: after the glanceable
  /// ones, before the odometer.
  static const unranked = 50;

  /// Field name in the webhook payload, such as `fuel_level_pct`.
  final String key;

  /// Human-readable name, such as "Fuel level".
  final String name;
  final String unit;

  /// A compact label for tiles, such as "Fuel", when [name] is long.
  final String? shortName;

  /// Where it's shown among a vehicle's values, lowest first.
  final int rank;
  final MetricFormat format;

  /// What a tile says.
  String get label => shortName ?? name;
}

/// The values Pitwall reads without a profile: the battery voltage the
/// adapter measures, and standard OBD-II values.
abstract final class Metrics {
  static const fuelLevel = Metric(
    key: 'fuel_level_pct',
    name: 'Fuel level',
    shortName: 'Fuel',
    unit: '%',
    rank: 0,
  );

  /// Measured by the adapter itself (`ATRV`), so it reads with the car
  /// switched off too.
  static const batteryVoltage = Metric(
    key: 'battery_v',
    name: 'Battery voltage',
    shortName: 'Battery',
    unit: 'V',
    rank: 1,
  );

  static const coolantTemperature = Metric(
    key: 'coolant_temp_c',
    name: 'Coolant temperature',
    shortName: 'Coolant',
    unit: '°C',
    rank: 2,
  );

  static const vehicleSpeed = Metric(
    key: 'speed_kmh',
    name: 'Vehicle speed',
    shortName: 'Speed',
    unit: 'km/h',
    rank: 3,
  );

  /// Also tells whether the engine runs.
  static const engineSpeed = Metric(
    key: 'rpm',
    name: 'Engine speed',
    shortName: 'RPM',
    unit: 'rpm',
    rank: 4,
  );

  static const runTime = Metric(
    key: 'engine_run_time_s',
    name: 'Run time since engine start',
    shortName: 'Run time',
    unit: 's',
    rank: 5,
    format: MetricFormat.duration,
  );

  /// Last, where it gets a full row.
  static const odometer = Metric(
    key: 'odometer_km',
    name: 'Odometer',
    unit: 'km',
    rank: 100,
  );
}
