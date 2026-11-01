import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform/trip_service_gateway.dart';
import '../core/session/car_state.dart';
import '../core/settings/settings.dart';
import '../core/vehicles/vehicle.dart';
import 'infrastructure.dart';
import 'session_state.dart';
import 'settings_state.dart';

enum TripPhase { idle, connecting, running, ending }

/// Why the last trip ended.
enum TripEnd {
  /// Asked to stop: the head unit disconnected, or the user stopped it.
  stopped,

  /// No vehicle has an adapter set.
  noVehicle,

  /// Bluetooth permission is missing, and there's no screen to ask on.
  permissionMissing,

  /// No adapter answered within the connect window.
  adapterNotFound,

  /// The car stopped answering for longer than the car-off window.
  carOff,

  /// The adapter dropped and didn't come back.
  adapterLost,
}

@immutable
class TripState {
  const TripState({
    this.phase = TripPhase.idle,
    this.vehicleId,
    this.startedAt,
    this.lastEnd,
  });

  final TripPhase phase;
  final String? vehicleId;
  final DateTime? startedAt;
  final TripEnd? lastEnd;

  bool get isActive => phase != TripPhase.idle;
}

/// How long the trip waits for things. Tests shorten these.
@immutable
class TripTiming {
  const TripTiming({
    this.retryDelay = const Duration(seconds: 10),
    this.connectWindow = const Duration(minutes: 3),
    this.carOffWindow = const Duration(minutes: 5),
    this.finalDeliveryWait = const Duration(seconds: 15),
  });

  /// Between connection attempts.
  final Duration retryDelay;

  /// How long to keep trying to reach an adapter, at the start or after it
  /// drops. Adapters often need a moment after the ignition comes on.
  final Duration connectWindow;

  /// How long a car may stay silent before the trip ends.
  final Duration carOffWindow;

  /// How long to wait for the final reading to be delivered.
  final Duration finalDeliveryWait;
}

final tripTimingProvider = Provider<TripTiming>((ref) => const TripTiming());

final tripProvider = NotifierProvider<TripController, TripState>(
  TripController.new,
);

/// Runs a trip in the background: started by Android when the car's head
/// unit connects, ended when it disconnects or the car goes quiet. Uses the
/// same session and sender as the screens, so Home shows the trip live.
class TripController extends Notifier<TripState> {
  bool _stopRequested = false;
  Completer<void>? _wake;

  TripServiceGateway get _gateway => ref.read(tripServiceGatewayProvider);
  SessionController get _session => ref.read(sessionProvider.notifier);
  SessionState get _sessionState => ref.read(sessionProvider);
  TripTiming get _timing => ref.read(tripTimingProvider);

  @override
  TripState build() {
    final gateway = ref.watch(tripServiceGatewayProvider);
    final commands = gateway.commands.listen((command) {
      switch (command) {
        case TripCommand.start:
          unawaited(_run());
        case TripCommand.stop:
          stop();
      }
    });
    ref.onDispose(commands.cancel);
    // Android needs to know which head unit starts a trip, even while the
    // app isn't running.
    ref.listen(
      appSettingsProvider.select(
        (settings) => switch (settings.value) {
          final value? =>
            value.wakeTrigger == WakeTrigger.carBluetooth
                ? value.headUnitAddress
                : null,
          null => null,
        },
      ),
      (_, address) => gateway.configure(headUnitAddress: address),
      fireImmediately: true,
    );
    // Android may have started the service before Dart was listening.
    Future.microtask(() async {
      if (await gateway.takeTripRequest()) unawaited(_run());
    });
    return const TripState();
  }

  /// Starts a trip from the app, through the service, as if the head unit
  /// had connected.
  Future<void> startManually() => _gateway.startService();

  /// Ends the trip after the current step; the last reading is still sent.
  void stop() {
    _stopRequested = true;
    final wake = _wake;
    if (wake != null && !wake.isCompleted) wake.complete();
  }

  Future<void> _run() async {
    if (state.isActive) return;
    _stopRequested = false;
    state = TripState(phase: TripPhase.connecting, startedAt: DateTime.now());
    final settings = await ref.read(appSettingsProvider.future);
    final candidates =
        settings.vehicles.where((v) => v.adapterAddress != null).toList()
          // The car seen most recently is the likeliest to be this one.
          ..sort((a, b) {
            final seenA = a.lastSeen, seenB = b.lastSeen;
            if (seenA == null) return seenB == null ? 0 : 1;
            return seenB == null ? -1 : seenB.compareTo(seenA);
          });
    if (candidates.isEmpty) return _finish(TripEnd.noVehicle);

    final (vehicle, problem) = await _connect(candidates);
    if (vehicle == null) return _finish(problem!);

    state = TripState(
      phase: TripPhase.running,
      vehicleId: vehicle.id,
      startedAt: state.startedAt,
    );
    final end = await _readLoop(vehicle, settings.interval);
    await _finish(end, vehicle: vehicle);
  }

  /// Tries each candidate's adapter until one connects, within the connect
  /// window.
  Future<(Vehicle?, TripEnd?)> _connect(List<Vehicle> candidates) async {
    final deadline = DateTime.now().add(_timing.connectWindow);
    while (!_stopRequested) {
      for (final vehicle in candidates) {
        if (_stopRequested) break;
        await _notify(_Stage.connecting, vehicle);
        await _session.connect(vehicle, askPermission: false);
        if (_sessionState.isConnected) return (vehicle, null);
        if (_sessionState.problem == SessionProblem.permissionDenied) {
          return (null, TripEnd.permissionMissing);
        }
      }
      if (DateTime.now().isAfter(deadline)) {
        return (null, TripEnd.adapterNotFound);
      }
      await _sleep(_timing.retryDelay);
    }
    return (null, TripEnd.stopped);
  }

  /// Reads and sends every [interval] until asked to stop, the car stays
  /// quiet too long, or the adapter can't be reached again.
  Future<TripEnd> _readLoop(Vehicle vehicle, Duration interval) async {
    DateTime? quietSince;
    while (!_stopRequested) {
      if (!_sessionState.isConnected) {
        final (reconnected, _) = await _connect([vehicle]);
        if (reconnected == null) {
          return _stopRequested ? TripEnd.stopped : TripEnd.adapterLost;
        }
      }
      if (_sessionState.carState == CarState.off) {
        quietSince ??= DateTime.now();
        if (DateTime.now().difference(quietSince) > _timing.carOffWindow) {
          return TripEnd.carOff;
        }
        await _notify(_Stage.waitingForCar, vehicle);
        await _session.checkCar();
      } else {
        final values = await _session.readAndSend();
        if (values != null && values.isNotEmpty) {
          quietSince = null;
          await _notify(_Stage.reading, vehicle, interval: interval);
        }
      }
      if (_sessionState.isConnected) await _sleep(interval);
    }
    return TripEnd.stopped;
  }

  Future<void> _finish(TripEnd end, {Vehicle? vehicle}) async {
    state = TripState(
      phase: TripPhase.ending,
      vehicleId: state.vehicleId,
      startedAt: state.startedAt,
    );
    final sender = ref.read(webhookSenderProvider);
    // Mark the end of the trip, but only if the trip got going: a trip
    // that never reached the car has nothing to close.
    if (vehicle != null) {
      await _notify(_Stage.ending, vehicle);
      try {
        await sender
            .send(device: vehicle.deviceId, values: const {}, connected: false)
            .timeout(_timing.finalDeliveryWait);
      } on TimeoutException {
        // It stays queued and goes out with the next delivery.
      }
    }
    if (_sessionState.phase != SessionPhase.idle) await _session.disconnect();
    ref.read(adapterLogProvider).note('Trip ended: ${end.name}');
    await _gateway.stopService();
    state = TripState(lastEnd: end);
  }

  /// Waits [duration], or less if a stop is requested meanwhile.
  Future<void> _sleep(Duration duration) {
    if (_stopRequested) return Future.value();
    final wake = Completer<void>();
    final timer = Timer(duration, wake.complete);
    _wake = wake;
    return wake.future.whenComplete(timer.cancel);
  }

  Future<void> _notify(
    _Stage stage,
    Vehicle vehicle, {
    Duration? interval,
  }) async {
    final text = switch (stage) {
      _Stage.connecting =>
        'Connecting to ${vehicle.adapterName ?? 'the adapter'}…',
      _Stage.reading => 'Reading ${vehicle.name} ${_every(interval!)}',
      _Stage.waitingForCar => 'Waiting for ${vehicle.name} to answer',
      _Stage.ending => 'Sending the last reading…',
    };
    await _gateway.updateNotification(text);
  }

  static String _every(Duration interval) => interval.inSeconds < 60
      ? 'every ${interval.inSeconds} s'
      : interval.inMinutes == 1
      ? 'every minute'
      : 'every ${interval.inMinutes} min';
}

enum _Stage { connecting, reading, waitingForCar, ending }
