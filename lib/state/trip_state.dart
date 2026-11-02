import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform/trip_service_gateway.dart';
import '../core/session/car_reading.dart';
import '../core/session/car_state.dart';
import '../core/trips/trip_notification_text.dart';
import '../core/trips/trip_target.dart';
import '../core/vehicles/vehicle.dart';
import 'infrastructure.dart';
import 'session_state.dart';
import 'settings_state.dart';

/// Why the last trip ended.
enum TripEnd {
  /// The user stopped it.
  stopped,

  /// No vehicle the trip is for has an adapter set.
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

/// A background trip: none, looking for the adapter, running, or ending.
@immutable
sealed class TripState {
  const TripState();

  /// The vehicle the trip is for, once its adapter answered.
  String? get vehicleId => null;

  bool get isActive => this is! TripIdle;
}

final class TripIdle extends TripState {
  const TripIdle({this.lastEnd});

  /// Why the last trip ended, if there was one.
  final TripEnd? lastEnd;
}

final class TripConnecting extends TripState {
  const TripConnecting();
}

final class TripRunning extends TripState {
  const TripRunning({required this.vehicleId, required this.since});

  @override
  final String vehicleId;

  /// When the trip first reached the car. Reconnecting doesn't change it.
  final DateTime since;
}

final class TripEnding extends TripState {
  const TripEnding({this.vehicleId});

  @override
  final String? vehicleId;
}

/// One trip's own state, so nothing carries over to the next.
class _TripRun {
  bool stopRequested = false;

  /// Wakes the trip from a wait when it's asked to stop.
  Completer<void>? wake;

  /// Whether readings went out; only then is there something to close.
  bool sentReadings = false;

  void stop() {
    stopRequested = true;
    final wake = this.wake;
    if (wake != null && !wake.isCompleted) wake.complete();
  }

  /// Waits [duration], or less if asked to stop meanwhile.
  Future<void> sleep(Duration duration) {
    if (stopRequested) return Future.value();
    final wake = Completer<void>();
    final timer = Timer(duration, wake.complete);
    this.wake = wake;
    return wake.future.whenComplete(timer.cancel);
  }
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

/// Runs a trip in the background: started by Android when a car's head
/// unit connects, ended when the car stops answering or the adapter can't
/// be reached. Uses the same session and sender as the screens, so Home
/// shows the trip live.
///
/// The head unit names the car, so the trip goes straight to its adapter.
/// It only starts trips: disconnecting from it, say to hand the stereo to
/// someone else, doesn't end one. One trip runs at a time.
class TripController extends Notifier<TripState> {
  /// The trip in progress, if any.
  _TripRun? _current;

  TripServiceGateway get _gateway => ref.read(tripServiceGatewayProvider);
  SessionController get _session => ref.read(sessionProvider.notifier);
  SessionState get _sessionState => ref.read(sessionProvider);
  TripTiming get _timing => ref.read(tripTimingProvider);

  @override
  TripState build() {
    final gateway = ref.watch(tripServiceGatewayProvider);
    final starts = gateway.starts.listen((target) => unawaited(_run(target)));
    ref.onDispose(starts.cancel);
    // Android needs to know which head units start a trip, even while the
    // app isn't running.
    Set<String>? configured;
    ref.listen(appSettingsProvider, (_, settings) {
      final headUnits = settings.value?.startingHeadUnits;
      if (headUnits == null || setEquals(headUnits, configured)) return;
      configured = headUnits;
      gateway.configure(headUnitAddresses: headUnits);
    }, fireImmediately: true);
    // Android may have started the service before Dart was listening.
    Future.microtask(() async {
      if (await gateway.takeTripRequest() case final target?) {
        unawaited(_run(target));
      }
    });
    return const TripIdle();
  }

  /// Starts a trip from the app, through the service, as if [vehicleId]'s
  /// head unit had connected. Without a vehicle, it tries every vehicle's
  /// adapter.
  Future<void> startManually({String? vehicleId}) => _gateway.startService(
    vehicleId == null ? const AnyVehicleTarget() : VehicleTarget(vehicleId),
  );

  /// Ends the trip after the current step; the last reading is still sent.
  void stop() => _current?.stop();

  /// Runs a trip for the vehicle [target] names, or whichever vehicle's
  /// adapter answers.
  Future<void> _run(TripTarget target) async {
    if (_current != null) return;
    final run = _current = _TripRun();
    state = const TripConnecting();
    final settings = await ref.read(appSettingsProvider.future);
    final candidates = settings.tripCandidates(target);
    if (candidates.isEmpty) return _finish(run, TripEnd.noVehicle);

    final (vehicle, problem) = await _connect(run, candidates);
    if (vehicle == null) return _finish(run, problem!);

    state = TripRunning(
      vehicleId: vehicle.id,
      since: switch (_sessionState) {
        SessionConnected(:final connectedAt) => connectedAt,
        _ => DateTime.now(),
      },
    );
    final end = await _readLoop(run, vehicle, settings.interval);
    await _finish(run, end, vehicle: vehicle);
  }

  /// Tries each candidate's adapter until one connects, within the connect
  /// window.
  Future<(Vehicle?, TripEnd?)> _connect(
    _TripRun run,
    List<Vehicle> candidates,
  ) async {
    final deadline = DateTime.now().add(_timing.connectWindow);
    while (!run.stopRequested) {
      for (final vehicle in candidates) {
        if (run.stopRequested) break;
        await _notify(TripNotificationText.connecting(vehicle));
        switch (await _session.connect(vehicle, askPermission: false)) {
          case null:
            return (vehicle, null);
          case SessionProblem.permissionDenied:
            return (null, TripEnd.permissionMissing);
          case _:
            break;
        }
      }
      if (DateTime.now().isAfter(deadline)) {
        return (null, TripEnd.adapterNotFound);
      }
      await run.sleep(_timing.retryDelay);
    }
    return (null, TripEnd.stopped);
  }

  /// Reads and sends every [interval] until asked to stop, the car stays
  /// quiet too long, or the adapter can't be reached again.
  Future<TripEnd> _readLoop(
    _TripRun run,
    Vehicle vehicle,
    Duration interval,
  ) async {
    DateTime? quietSince;
    while (!run.stopRequested) {
      if (!_sessionState.isConnected) {
        final (reconnected, _) = await _connect(run, [vehicle]);
        if (reconnected == null) {
          return run.stopRequested ? TripEnd.stopped : TripEnd.adapterLost;
        }
      }
      if (_sessionState case SessionConnected(carState: CarState.off)) {
        quietSince ??= DateTime.now();
        if (DateTime.now().difference(quietSince) > _timing.carOffWindow) {
          return TripEnd.carOff;
        }
        await _notify(TripNotificationText.waitingForCar(vehicle));
        await _session.checkCar();
      } else {
        final reading = await _session.readAndSend();
        if (reading case CarAnswered(:final values) when values.isNotEmpty) {
          quietSince = null;
          run.sentReadings = true;
          await _notify(TripNotificationText.reading(vehicle, interval));
        }
      }
      if (_sessionState.isConnected) await run.sleep(interval);
    }
    return TripEnd.stopped;
  }

  /// Tells the receiver the car disconnected, if readings went out.
  Future<void> _close(_TripRun run, Vehicle vehicle) async {
    if (!run.sentReadings) return;
    await _notify(TripNotificationText.ending);
    try {
      await ref
          .read(webhookSenderProvider)
          .send(device: vehicle.deviceId, values: const {}, connected: false)
          .timeout(_timing.finalDeliveryWait);
    } on TimeoutException {
      // It stays queued and goes out with the next delivery.
    }
  }

  Future<void> _finish(_TripRun run, TripEnd end, {Vehicle? vehicle}) async {
    state = TripEnding(vehicleId: vehicle?.id);
    // Mark the end, but only after readings: a trip that never sent one,
    // like a stereo waking with the car parked, has nothing to close.
    if (vehicle != null) await _close(run, vehicle);
    if (_sessionState is! SessionIdle) await _session.disconnect();
    ref.read(adapterLogProvider).note('Trip ended: ${end.name}');
    await _gateway.stopService();
    _current = null;
    state = TripIdle(lastEnd: end);
  }

  Future<void> _notify(String text) => _gateway.updateNotification(text);
}
