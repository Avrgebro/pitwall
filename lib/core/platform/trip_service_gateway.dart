import 'dart:async';

import 'package:flutter/services.dart';

import '../trips/trip_target.dart';

/// The Android trip service, behind an interface so the trip controller can
/// be tested without a phone. Backed by `ServiceBridge.kt`.
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

  /// Starts the service from the app, for [vehicleId] or any vehicle. It
  /// comes back through [starts], as a head unit's start does.
  Future<void> startService({String? vehicleId});

  /// Stops the service once the trip is over.
  Future<void> stopService();

  Future<void> updateNotification(String text);
}

class AndroidTripServiceGateway implements TripServiceGateway {
  AndroidTripServiceGateway() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'tripStart':
          try {
            _starts.add(TripTarget.fromArguments(call.arguments));
          } on FormatException catch (error, stack) {
            _starts.addError(error, stack);
          }
      }
    });
  }

  static const _channel = MethodChannel('pitwall/service');
  final _starts = StreamController<TripTarget>.broadcast();

  @override
  Stream<TripTarget> get starts => _starts.stream;

  @override
  Future<TripTarget?> takeTripRequest() async {
    final request = await _channel.invokeMethod<Object?>('takeTripRequest');
    return request == null ? null : TripTarget.fromArguments(request);
  }

  @override
  Future<void> configure({required Set<String> headUnitAddresses}) =>
      _channel.invokeMethod<void>('configure', {
        'headUnitAddresses': [...headUnitAddresses],
      });

  @override
  Future<void> startService({String? vehicleId}) => _channel.invokeMethod<void>(
    'startService',
    switch (vehicleId) {
      final id? => VehicleTarget(id),
      null => const AnyVehicleTarget(),
    }.toArguments(),
  );

  @override
  Future<void> stopService() => _channel.invokeMethod<void>('stopService');

  @override
  Future<void> updateNotification(String text) =>
      _channel.invokeMethod<void>('updateNotification', {'text': text});
}
