import 'dart:async';

import 'package:flutter/services.dart';

/// Android started the trip service: a car's head unit connected, or the
/// app started a trip itself. Android only ever starts trips; the trip
/// decides when it's over.
final class StartTrip {
  const StartTrip([this.headUnit]);

  /// The head unit's Bluetooth address; null when the app asked.
  final String? headUnit;
}

/// The Android trip service, behind an interface so the trip controller can
/// be tested without a phone. Backed by `ServiceBridge.kt`.
abstract interface class TripServiceGateway {
  /// Trips Android started.
  Stream<StartTrip> get starts;

  /// The trip Android asked for before Dart was ready to hear it, if any.
  /// Asking also tells Android that Dart is now listening.
  Future<StartTrip?> takeTripRequest();

  /// The head units whose connection starts a trip, one per vehicle at
  /// most. Android keeps them, so it can start a trip with the app closed.
  Future<void> configure({required Set<String> headUnitAddresses});

  /// Starts the service from the app, as if the head unit had connected.
  Future<void> startService();

  /// Stops the service once the trip is over.
  Future<void> stopService();

  Future<void> updateNotification(String text);
}

class AndroidTripServiceGateway implements TripServiceGateway {
  AndroidTripServiceGateway() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'tripStart':
          _starts.add(StartTrip(_headUnit(call.arguments)));
      }
    });
  }

  static const _channel = MethodChannel('pitwall/service');
  final _starts = StreamController<StartTrip>.broadcast();

  @override
  Stream<StartTrip> get starts => _starts.stream;

  static String? _headUnit(Object? arguments) =>
      arguments is Map ? arguments['headUnit'] as String? : null;

  @override
  Future<StartTrip?> takeTripRequest() async {
    final request = await _channel.invokeMethod<Object?>('takeTripRequest');
    return request == null ? null : StartTrip(_headUnit(request));
  }

  @override
  Future<void> configure({required Set<String> headUnitAddresses}) =>
      _channel.invokeMethod<void>('configure', {
        'headUnitAddresses': [...headUnitAddresses],
      });

  @override
  Future<void> startService() => _channel.invokeMethod<void>('startService');

  @override
  Future<void> stopService() => _channel.invokeMethod<void>('stopService');

  @override
  Future<void> updateNotification(String text) =>
      _channel.invokeMethod<void>('updateNotification', {'text': text});
}
