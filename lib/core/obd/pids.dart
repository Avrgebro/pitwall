import '../readings/metric.dart';

/// Standard OBD-II mode 01 values Pitwall knows how to decode.
///
/// Formulas follow SAE J1979. `data` is the reply payload after the
/// `41 <pid>` header, one int per byte.
class PidDefinition {
  const PidDefinition({
    required this.pid,
    required this.metric,
    required this.length,
    required this.decode,
  });

  final int pid;

  /// What the value is, and its payload key.
  final Metric metric;

  /// Number of data bytes the reply carries.
  final int length;

  final double Function(List<int> data) decode;
}

final List<PidDefinition> standardPids = [
  PidDefinition(
    pid: 0x05,
    metric: Metrics.coolantTemperature,
    length: 1,
    decode: (d) => d[0] - 40.0,
  ),
  PidDefinition(
    pid: 0x0C,
    metric: Metrics.engineSpeed,
    length: 2,
    decode: (d) => (d[0] * 256 + d[1]) / 4,
  ),
  PidDefinition(
    pid: 0x0D,
    metric: Metrics.vehicleSpeed,
    length: 1,
    decode: (d) => d[0].toDouble(),
  ),
  PidDefinition(
    pid: 0x1F,
    metric: Metrics.runTime,
    length: 2,
    decode: (d) => (d[0] * 256 + d[1]).toDouble(),
  ),
  PidDefinition(
    pid: 0x2F,
    metric: Metrics.fuelLevel,
    length: 1,
    decode: (d) => d[0] * 100 / 255,
  ),
  PidDefinition(
    pid: 0xA6,
    metric: Metrics.odometer,
    length: 4,
    decode: (d) => ((d[0] << 24) | (d[1] << 16) | (d[2] << 8) | d[3]) / 10,
  ),
];

final Map<int, PidDefinition> standardPidsById = {
  for (final definition in standardPids) definition.pid: definition,
};
