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
  Stream<TripTarget> get starts;

  /// The trip Android asked for before Dart was ready to hear it, if any.
  /// Asking also tells Android that Dart is now listening.
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
  void tripStart(TripTargetMessage target) => _starts.add(target.toTarget());

  @override
  Future<TripTarget?> takeTripRequest() async =>
      (await _api.takeTripRequest())?.toTarget();

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

/// What the app asks for, as it travels to Android.
extension AppTripTargetMessages on AppTripTarget {
  AppTripTargetMessage toMessage() => switch (this) {
    VehicleTarget(:final id) => VehicleMessage(id: id),
    AnyVehicleTarget() => AnyVehicleMessage(),
  };
}

/// A trip target as it arrives from Android.
extension TripTargetMessageTargets on TripTargetMessage {
  TripTarget toTarget() => switch (this) {
    HeadUnitMessage(:final address) => HeadUnitTarget(address),
    AppRequestMessage(target: VehicleMessage(:final id)) => VehicleTarget(id),
    AppRequestMessage(target: AnyVehicleMessage()) => const AnyVehicleTarget(),
  };
}
