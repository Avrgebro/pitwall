import 'dart:async';

import 'package:flutter/services.dart';

enum TripCommand {
  /// Android started the trip service (the car's head unit connected).
  start,

  /// Android asks the trip to end (the head unit disconnected).
  stop,
}

/// The Android trip service, behind an interface so the trip controller can
/// be tested without a phone. Backed by `ServiceBridge.kt`.
abstract interface class TripServiceGateway {
  /// Commands from Android.
  Stream<TripCommand> get commands;

  /// Whether Android asked for a trip before Dart was ready to hear it.
  /// Asking also tells Android that Dart is now listening.
  Future<bool> takeTripRequest();

  /// Which head unit's connection starts a trip; null turns that off.
  Future<void> configure({String? headUnitAddress});

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
          _commands.add(TripCommand.start);
        case 'tripStop':
          _commands.add(TripCommand.stop);
      }
    });
  }

  static const _channel = MethodChannel('pitwall/service');
  final _commands = StreamController<TripCommand>.broadcast();

  @override
  Stream<TripCommand> get commands => _commands.stream;

  @override
  Future<bool> takeTripRequest() async =>
      await _channel.invokeMethod<bool>('takeTripRequest') ?? false;

  @override
  Future<void> configure({String? headUnitAddress}) => _channel
      .invokeMethod<void>('configure', {'headUnitAddress': headUnitAddress});

  @override
  Future<void> startService() => _channel.invokeMethod<void>('startService');

  @override
  Future<void> stopService() => _channel.invokeMethod<void>('stopService');

  @override
  Future<void> updateNotification(String text) =>
      _channel.invokeMethod<void>('updateNotification', {'text': text});
}
