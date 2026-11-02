import 'dart:async';

import 'package:flutter/services.dart';

import '../trips/trip_target.dart';

/// The Android trip service, behind an interface so the trip controller can
/// be tested without a phone. Backed by `ServiceBridge.kt`.
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

  /// Starts the service from the app. The [target] comes back through
  /// [starts], as a head unit's does.
  Future<void> startService(TripTarget target);

  /// Stops the service once the trip is over.
  Future<void> stopService();

  Future<void> updateNotification(String text);
}

class AndroidTripServiceGateway implements TripServiceGateway {
  AndroidTripServiceGateway() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'tripStart':
          _starts.add(_decode(call.arguments));
      }
    });
  }

  static const _channel = MethodChannel('pitwall/service');
  final _starts = StreamController<TripTarget>.broadcast();

  @override
  Stream<TripTarget> get starts => _starts.stream;

  /// A target travels as `headUnit` or `vehicleId`, or neither for any
  /// vehicle.
  static TripTarget _decode(Object? arguments) {
    final map = arguments is Map ? arguments : const {};
    return switch ((map['headUnit'], map['vehicleId'])) {
      (final String address, _) => HeadUnitTarget(address),
      (_, final String id) => VehicleTarget(id),
      _ => const AnyVehicleTarget(),
    };
  }

  static Map<String, String> _encode(TripTarget target) => switch (target) {
    HeadUnitTarget(:final address) => {'headUnit': address},
    VehicleTarget(:final id) => {'vehicleId': id},
    AnyVehicleTarget() => const {},
  };

  @override
  Future<TripTarget?> takeTripRequest() async {
    final request = await _channel.invokeMethod<Object?>('takeTripRequest');
    return request == null ? null : _decode(request);
  }

  @override
  Future<void> configure({required Set<String> headUnitAddresses}) =>
      _channel.invokeMethod<void>('configure', {
        'headUnitAddresses': [...headUnitAddresses],
      });

  @override
  Future<void> startService(TripTarget target) =>
      _channel.invokeMethod<void>('startService', _encode(target));

  @override
  Future<void> stopService() => _channel.invokeMethod<void>('stopService');

  @override
  Future<void> updateNotification(String text) =>
      _channel.invokeMethod<void>('updateNotification', {'text': text});
}
