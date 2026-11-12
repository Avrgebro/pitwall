import '../trips/trip_target.dart';
import '../vehicles/vehicle.dart';

/// The user's settings, except the webhook URL and credentials. Those work
/// like passwords, so they're kept apart in secure storage (see
/// `SettingsStore`).
class AppSettings {
  const AppSettings({
    this.vehicles = const [],
    this.interval = defaultInterval,
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

  /// Whether first-run setup has been completed.
  final bool setupDone;

  /// The vehicle whose adapter has [address], if any.
  Vehicle? vehicleForAdapter(String address) =>
      vehicles.where((v) => v.adapter?.address == address).firstOrNull;

  /// The vehicle whose trips start when the head unit at [address]
  /// connects, if any.
  Vehicle? vehicleForHeadUnit(String address) => vehicles
      .where((v) => _sameAddress(v.startingHeadUnit, address))
      .firstOrNull;

  /// The vehicle the head unit at [address] belongs to, whatever starts its
  /// trips. A head unit belongs to one vehicle at most.
  Vehicle? headUnitOwner(String address) => vehicles
      .where((v) => _sameAddress(v.headUnit?.address, address))
      .firstOrNull;

  /// The vehicle other than [vehicleId] the head unit at [address] belongs
  /// to, if any: then [vehicleId] can't have it.
  Vehicle? otherHeadUnitOwner(String address, {required String vehicleId}) =>
      switch (headUnitOwner(address)) {
        final owner? when owner.id != vehicleId => owner,
        _ => null,
      };

  /// Every head unit that starts a trip, for Android to watch for.
  /// The adapters whose waking starts a vehicle's trips, which Android
  /// watches for even while the app isn't running.
  Set<String> get startingAdapters => {
    for (final vehicle in vehicles)
      if (vehicle.startingAdapter case final address?) address.toUpperCase(),
  };

  /// The vehicle whose trips start when the adapter at [address] wakes, if
  /// any.
  Vehicle? vehicleForWakingAdapter(String address) => vehicles
      .where((v) => _sameAddress(v.startingAdapter, address))
      .firstOrNull;

  Set<String> get startingHeadUnits => {
    for (final vehicle in vehicles)
      if (vehicle.startingHeadUnit case final address?) address.toUpperCase(),
  };

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

  /// The vehicles a trip for [target] may connect to, in the order to try
  /// them. Only vehicles with an adapter count.
  List<Vehicle> tripCandidates(TripTarget target) => switch (target) {
    HeadUnitTarget(:final address) => [?vehicleForHeadUnit(address)],
    AdapterTarget(:final address) => [?vehicleForWakingAdapter(address)],
    VehicleTarget(:final id) => [?vehicleById(id)],
    // The car seen most recently is the likeliest to be this one.
    AnyVehicleTarget() => [...vehicles]..sort(_mostRecentFirst),
  }.where((v) => v.adapter != null).toList();

  static int _mostRecentFirst(Vehicle a, Vehicle b) {
    final seenA = a.lastSeen, seenB = b.lastSeen;
    if (seenA == null) return seenB == null ? 0 : 1;
    return seenB == null ? -1 : seenB.compareTo(seenA);
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
    bool? setupDone,
  }) => AppSettings(
    vehicles: vehicles ?? this.vehicles,
    interval: interval ?? this.interval,
    setupDone: setupDone ?? this.setupDone,
  );

  Map<String, Object?> toJson() => {
    'vehicles': [for (final vehicle in vehicles) vehicle.toJson()],
    'intervalSeconds': interval.inSeconds,
    'setupDone': setupDone,
  };

  /// Tolerates missing or wrongly typed fields, falling back to defaults.
  factory AppSettings.fromJson(Map<String, Object?> json) {
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
      setupDone: json['setupDone'] == true,
    );
  }
}

/// Bluetooth addresses compare without case: Android reports them upper
/// case, but stored ones may differ.
bool _sameAddress(String? a, String b) =>
    a != null && a.toUpperCase() == b.toUpperCase();
