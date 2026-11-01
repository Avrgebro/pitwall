import '../vehicles/vehicle.dart';

/// The user's settings, except the webhook URL. That one works like a
/// password, so it's kept apart in secure storage (see `SettingsStore`).
class AppSettings {
  const AppSettings({
    this.vehicles = const [],
    this.interval = defaultInterval,
  });

  static const defaultInterval = Duration(minutes: 1);
  static const minInterval = Duration(seconds: 10);

  final List<Vehicle> vehicles;

  /// How often a reading is sent while driving.
  final Duration interval;

  /// The vehicle whose adapter has [address], if any.
  Vehicle? vehicleForAdapter(String address) =>
      vehicles.where((v) => v.adapterAddress == address).firstOrNull;

  /// Adds [vehicle], or replaces the one with the same id.
  AppSettings withVehicle(Vehicle vehicle) {
    final index = vehicles.indexWhere((v) => v.id == vehicle.id);
    return copyWith(
      vehicles: index == -1
          ? [...vehicles, vehicle]
          : ([...vehicles]..[index] = vehicle),
    );
  }

  AppSettings withoutVehicle(String id) =>
      copyWith(vehicles: vehicles.where((v) => v.id != id).toList());

  AppSettings copyWith({List<Vehicle>? vehicles, Duration? interval}) =>
      AppSettings(
        vehicles: vehicles ?? this.vehicles,
        interval: interval ?? this.interval,
      );

  Map<String, Object?> toJson() => {
    'vehicles': [for (final vehicle in vehicles) vehicle.toJson()],
    'intervalSeconds': interval.inSeconds,
  };

  /// Tolerates missing or wrongly typed fields. Also reads the earlier
  /// single-car format, where the car's settings sat at the top level.
  factory AppSettings.fromJson(Map<String, Object?> json) {
    if (isLegacy(json)) {
      return AppSettings(vehicles: [Vehicle.fromJson(json)]);
    }
    final seconds = json['intervalSeconds'];
    return AppSettings(
      vehicles: switch (json['vehicles']) {
        final List<Object?> list => [
          for (final item in list)
            if (item is Map<String, Object?>) Vehicle.fromJson(item),
        ],
        _ => const [],
      },
      interval: seconds is num && seconds >= minInterval.inSeconds
          ? Duration(seconds: seconds.toInt())
          : defaultInterval,
    );
  }

  /// Whether [json] is the earlier single-car format.
  static bool isLegacy(Map<String, Object?> json) =>
      !json.containsKey('vehicles') &&
      (json.containsKey('adapterAddress') || json.containsKey('deviceName'));
}

/// Returns why [url] can't be used as a webhook, or null if it can.
String? webhookUrlProblem(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return 'Enter a full URL, like https://example.com/api/webhook/…';
  }
  if (uri.scheme != 'https' && uri.scheme != 'http') {
    return 'The URL must start with https:// or http://';
  }
  return null;
}
