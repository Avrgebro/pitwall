import '../vehicles/vehicle.dart';

/// What starts Pitwall when a drive begins.
enum WakeTrigger {
  /// The phone connecting to the car's own Bluetooth (head unit).
  carBluetooth,

  /// Android detecting that the phone is in a moving vehicle.
  drivingDetection,
}

/// The user's settings, except the webhook URL and credentials. Those work
/// like passwords, so they're kept apart in secure storage (see
/// `SettingsStore`).
class AppSettings {
  const AppSettings({
    this.vehicles = const [],
    this.interval = defaultInterval,
    this.wakeTrigger = WakeTrigger.carBluetooth,
    this.headUnitAddress,
    this.headUnitName,
    this.setupDone = false,
  });

  static const defaultInterval = Duration(minutes: 1);
  static const minInterval = Duration(seconds: 10);

  /// The reading intervals offered to the user.
  static const intervalChoices = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 10),
  ];

  final List<Vehicle> vehicles;

  /// How often a reading is sent while driving.
  final Duration interval;

  final WakeTrigger wakeTrigger;

  /// The car's Bluetooth head unit, for [WakeTrigger.carBluetooth].
  final String? headUnitAddress;
  final String? headUnitName;

  /// Whether first-run setup has been completed.
  final bool setupDone;

  /// The vehicle whose adapter has [address], if any.
  Vehicle? vehicleForAdapter(String address) =>
      vehicles.where((v) => v.adapterAddress == address).firstOrNull;

  Vehicle? vehicleById(String id) =>
      vehicles.where((v) => v.id == id).firstOrNull;

  /// The vehicle seen most recently, or the first one if none was seen.
  Vehicle? get mostRecentVehicle {
    Vehicle? recent;
    for (final vehicle in vehicles) {
      final seen = vehicle.lastSeen;
      if (seen == null) continue;
      if (recent == null || seen.isAfter(recent.lastSeen!)) recent = vehicle;
    }
    return recent ?? vehicles.firstOrNull;
  }

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

  AppSettings copyWith({
    List<Vehicle>? vehicles,
    Duration? interval,
    WakeTrigger? wakeTrigger,
    Object? headUnitAddress = _keep,
    Object? headUnitName = _keep,
    bool? setupDone,
  }) => AppSettings(
    vehicles: vehicles ?? this.vehicles,
    interval: interval ?? this.interval,
    wakeTrigger: wakeTrigger ?? this.wakeTrigger,
    headUnitAddress: headUnitAddress == _keep
        ? this.headUnitAddress
        : headUnitAddress as String?,
    headUnitName: headUnitName == _keep
        ? this.headUnitName
        : headUnitName as String?,
    setupDone: setupDone ?? this.setupDone,
  );

  Map<String, Object?> toJson() => {
    'vehicles': [for (final vehicle in vehicles) vehicle.toJson()],
    'intervalSeconds': interval.inSeconds,
    'wakeTrigger': wakeTrigger.name,
    'headUnitAddress': headUnitAddress,
    'headUnitName': headUnitName,
    'setupDone': setupDone,
  };

  /// Tolerates missing or wrongly typed fields. Also reads the earlier
  /// single-car format, where the car's settings sat at the top level.
  factory AppSettings.fromJson(Map<String, Object?> json) {
    if (isLegacy(json)) {
      return AppSettings(vehicles: [Vehicle.fromJson(json)], setupDone: true);
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
      wakeTrigger:
          WakeTrigger.values.asNameMap()[json['wakeTrigger']] ??
          WakeTrigger.carBluetooth,
      headUnitAddress: _string(json['headUnitAddress']),
      headUnitName: _string(json['headUnitName']),
      setupDone: json['setupDone'] == true,
    );
  }

  /// Whether [json] is the earlier single-car format.
  static bool isLegacy(Map<String, Object?> json) =>
      !json.containsKey('vehicles') &&
      (json.containsKey('adapterAddress') || json.containsKey('deviceName'));
}

const _keep = Object();

String? _string(Object? value) => value is String ? value : null;

enum WebhookUrlProblem {
  /// Not a full URL with a scheme and host.
  incomplete,

  /// A scheme other than https or http.
  unsupportedScheme,
}

/// Returns why [url] can't be used as a webhook, or null if it can.
WebhookUrlProblem? validateWebhookUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return WebhookUrlProblem.incomplete;
  }
  if (uri.scheme != 'https' && uri.scheme != 'http') {
    return WebhookUrlProblem.unsupportedScheme;
  }
  return null;
}
