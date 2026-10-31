/// Standard OBD-II mode 01 values Pitwall knows how to decode.
///
/// Formulas follow SAE J1979. `data` is the reply payload after the
/// `41 <pid>` header, one int per byte.
class PidDefinition {
  const PidDefinition({
    required this.pid,
    required this.key,
    required this.unit,
    required this.length,
    required this.decode,
  });

  final int pid;

  /// Field name in the webhook payload, e.g. `fuel_level_pct`.
  final String key;

  final String unit;

  /// Number of data bytes the reply carries.
  final int length;

  final double Function(List<int> data) decode;
}

final List<PidDefinition> standardPids = [
  PidDefinition(
    pid: 0x05,
    key: 'coolant_temp_c',
    unit: '°C',
    length: 1,
    decode: (d) => d[0] - 40.0,
  ),
  PidDefinition(
    pid: 0x0C,
    key: 'rpm',
    unit: 'rpm',
    length: 2,
    decode: (d) => (d[0] * 256 + d[1]) / 4,
  ),
  PidDefinition(
    pid: 0x0D,
    key: 'speed_kmh',
    unit: 'km/h',
    length: 1,
    decode: (d) => d[0].toDouble(),
  ),
  PidDefinition(
    pid: 0x2F,
    key: 'fuel_level_pct',
    unit: '%',
    length: 1,
    decode: (d) => d[0] * 100 / 255,
  ),
  PidDefinition(
    pid: 0xA6,
    key: 'odometer_km',
    unit: 'km',
    length: 4,
    decode: (d) => ((d[0] << 24) | (d[1] << 16) | (d[2] << 8) | d[3]) / 10,
  ),
];

final Map<int, PidDefinition> standardPidsById = {
  for (final definition in standardPids) definition.pid: definition,
};
