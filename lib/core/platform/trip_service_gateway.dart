import 'dart:async';

import '../trips/trip_target.dart';
import 'messages.g.dart';

/// The Android trip service, behind an interface so the trip controller can
/// be tested without a phone. Backed by `ServiceBridge.kt`, through the
/// messages in `pigeons/messages.dart`.
///
/// Android only ever starts trips; the trip decides when it's over.
abstract interface class TripServiceGateway {
  /// Trips Android started: a car's head unit connected, or the app asked.
  /// A start whose target can't be read arrives as a [FormatException].
  Stream<TripTarget> get starts;

  /// The trip Android asked for before Dart was ready to hear it, if any.
  /// Asking also tells Android that Dart is now listening. Throws
  /// [FormatException] if its target can't be read.
  Future<TripTarget?> takeTripRequest();

  /// The head units whose connection starts a trip, one per vehicle at
  /// most. Android keeps them, so it can start a trip with the app closed.
  Future<void> configure({required Set<String> headUnitAddresses});

  /// Starts the service from the app for [target]. It comes back through
  /// [starts], as a head unit's start does.
  Future<void> startService(AppTripTarget target);

  /// Stops the service once the trip is over.
  Future<void> stopService();

  Future<void> updateNotification(String text);
}

class AndroidTripServiceGateway implements TripServiceGateway, TripStartApi {
  AndroidTripServiceGateway() {
    TripStartApi.setUp(this);
  }

  final _api = TripServiceApi();
  final _starts = StreamController<TripTarget>.broadcast();

  @override
  Stream<TripTarget> get starts => _starts.stream;

  /// Called by Android with each trip it starts.
  @override
  void tripStart(TripTargetMessage target) {
    try {
      _starts.add(tripTargetFrom(target));
    } on FormatException catch (error, stack) {
      _starts.addError(error, stack);
    }
  }

  @override
  Future<TripTarget?> takeTripRequest() async =>
      switch (await _api.takeTripRequest()) {
        final message? => tripTargetFrom(message),
        null => null,
      };

  @override
  Future<void> configure({required Set<String> headUnitAddresses}) =>
      _api.configure([...headUnitAddresses]);

  @override
  Future<void> startService(AppTripTarget target) =>
      _api.startService(target.toMessage());

  @override
  Future<void> stopService() => _api.stopService();

  @override
  Future<void> updateNotification(String text) => _api.updateNotification(text);
}

/// A trip target as it travels to Android.
extension TripTargetMessages on TripTarget {
  TripTargetMessage toMessage() => switch (this) {
    HeadUnitTarget(:final address) => TripTargetMessage(
      kind: TripTargetKind.headUnit,
      address: address,
    ),
    VehicleTarget(:final id) => TripTargetMessage(
      kind: TripTargetKind.vehicle,
      vehicleId: id,
    ),
    AnyVehicleTarget() => TripTargetMessage(kind: TripTargetKind.anyVehicle),
  };
}

/// The target [message] names. A kind without what it names, or with what
/// another kind names, is a mistake in the bridge: a [FormatException],
/// rather than a trip for any vehicle.
TripTarget tripTargetFrom(TripTargetMessage message) => switch ((
  message.kind,
  message.address,
  message.vehicleId,
)) {
  (TripTargetKind.headUnit, final address?, null) => HeadUnitTarget(address),
  (TripTargetKind.vehicle, null, final id?) => VehicleTarget(id),
  (TripTargetKind.anyVehicle, null, null) => const AnyVehicleTarget(),
  _ => throw FormatException('Not a trip target: ${message.kind.name}'),
};
