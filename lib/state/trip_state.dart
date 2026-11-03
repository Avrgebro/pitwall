import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform/trip_service_gateway.dart';
import '../core/session/car_reading.dart';
import '../core/session/car_state.dart';
import '../core/trips/trip_notification_text.dart';
import '../core/trips/trip_target.dart';
import '../core/vehicles/vehicle.dart';
import 'infrastructure.dart';
import 'reading_keeper.dart';
import 'session_state.dart';
import 'settings_state.dart';

/// Why the last trip ended.
enum TripEnd {
  /// The user stopped it.
  stopped,

  /// No vehicle the trip is for has an adapter set, or the trip's vehicle
  /// was deleted.
  noVehicle,

  /// Bluetooth permission is missing, and there's no screen to ask on.
  permissionMissing,

  /// No adapter answered within the connect window.
  adapterNotFound,

  /// The car stopped answering for longer than the car-off window.
  carOff,

  /// The adapter dropped and didn't come back.
  adapterLost,

  /// Something unexpected went wrong; the adapter log says what.
  failed,
}

/// A background trip: none, looking for the adapter, running, or ending.
@immutable
sealed class TripState {
  const TripState();

  bool get isActive => this is! TripIdle;
}

final class TripIdle extends TripState {
  const TripIdle({this.lastEnd});

  /// Why the last trip ended, if there was one.
  final TripEnd? lastEnd;
}

final class TripConnecting extends TripState {
  const TripConnecting({this.vehicleIds = const {}});

  /// The vehicles whose adapters it's trying, once the settings say which.
  final Set<String> vehicleIds;
}

final class TripRunning extends TripState {
  const TripRunning({required this.vehicleId, required this.since});

  final String vehicleId;

  /// When the trip first reached the car. Reconnecting doesn't change it.
  final DateTime since;
}

final class TripEnding extends TripState {
  const TripEnding();
}

/// How looking for an adapter ended.
sealed class _Search {
  const _Search();
}

/// A vehicle's adapter answered: the vehicle, and the session with it.
final class _Found extends _Search {
  const _Found(this.vehicle, this.session);

  final Vehicle vehicle;
  final SessionConnected session;
}

/// None did, and why the trip ends.
final class _NotFound extends _Search {
  const _NotFound(this.end);

  final TripEnd end;
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
  ReadingKeeper get _readings => ref.read(readingKeeperProvider);
  SessionState get _sessionState => ref.read(sessionProvider);
  TripTiming get _timing => ref.read(tripTimingProvider);

  @override
  TripState build() {
    final gateway = ref.watch(tripServiceGatewayProvider);
    final starts = gateway.starts.listen(
      (target) => unawaited(_run(target)),
      onError: _refuse,
    );
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
      try {
        if (await gateway.takeTripRequest() case final target?) {
          unawaited(_run(target));
        }
      } on FormatException catch (error, stack) {
        _refuse(error, stack);
      } on PlatformException catch (error, stack) {
        _refuse(error, stack);
      }
    });
    return const TripIdle();
  }

  /// Starts a trip from the app, through the service, as if the vehicle's
  /// head unit had connected; for any vehicle, it tries every adapter.
  Future<void> startManually(AppTripTarget target) =>
      _gateway.startService(target);

  /// Ends the trip after the current step; the last reading is still sent.
  void stop() => _current?.stop();

  /// Runs a trip for the vehicle [target] names, or whichever vehicle's
  /// adapter answers. However it ends, even by an error, it finishes, so
  /// the next trip can start.
  Future<void> _run(TripTarget target) async {
    if (_current != null) return;
    final run = _current = _TripRun();
    var end = TripEnd.stopped;
    Vehicle? vehicle;
    try {
      state = const TripConnecting();
      final settings = await ref.read(appSettingsProvider.future);
      final candidates = settings.tripCandidates(target);
      if (candidates.isEmpty) {
        end = TripEnd.noVehicle;
        return;
      }
      state = TripConnecting(vehicleIds: {for (final v in candidates) v.id});
      switch (await _connect(run, candidates)) {
        case _NotFound(end: final notFound):
          end = notFound;
        case final _Found found:
          vehicle = found.vehicle;
          state = TripRunning(
            vehicleId: found.vehicle.id,
            since: found.session.connectedAt,
          );
          end = await _readLoop(run, found, settings.interval);
      }
    } on Object catch (error, stack) {
      end = TripEnd.failed;
      _report('Trip failed', error, stack);
    } finally {
      await _finish(run, end, vehicle: vehicle);
    }
  }

  /// Tries each candidate's adapter until one connects, within the connect
  /// window.
  Future<_Search> _connect(_TripRun run, List<Vehicle> candidates) async {
    final deadline = DateTime.now().add(_timing.connectWindow);
    while (!run.stopRequested) {
      for (final vehicle in candidates) {
        if (run.stopRequested) break;
        await _notify(TripNotificationText.connecting(vehicle));
        switch (await _session.connect(vehicle)) {
          case StepDone(value: final session):
            return _Found(vehicle, session);
          case StepFailed(problem: ConnectionProblem.permissionDenied):
            return const _NotFound(TripEnd.permissionMissing);
          case StepFailed() || StepRefused():
            break;
        }
      }
      if (DateTime.now().isAfter(deadline)) {
        return const _NotFound(TripEnd.adapterNotFound);
      }
      await run.sleep(_timing.retryDelay);
    }
    return const _NotFound(TripEnd.stopped);
  }

  /// Reads and sends every [interval] until asked to stop, the car stays
  /// quiet too long, or the adapter can't be reached again. While the car
  /// is silent, it only checks whether it answers again.
  Future<TripEnd> _readLoop(
    _TripRun run,
    _Found reached,
    Duration interval,
  ) async {
    var vehicle = reached.vehicle;
    var silent = reached.session.carState == CarState.off;
    var lost = false;
    DateTime? quietSince;
    while (!run.stopRequested) {
      if (lost) {
        // As it is now, with any new adapter.
        final current = ref.read(vehicleProvider(vehicle.id));
        if (current == null) return TripEnd.noVehicle;
        vehicle = current;
        switch (await _connect(run, [vehicle])) {
          // Not finding it again is losing it.
          case _NotFound(end: TripEnd.adapterNotFound):
            return TripEnd.adapterLost;
          case _NotFound(:final end):
            return end;
          case _Found(:final session):
            lost = false;
            // A car that answers again starts a new quiet window.
            if (session.carState != CarState.off) quietSince = null;
            silent = session.carState == CarState.off;
        }
      }
      if (silent) {
        quietSince ??= DateTime.now();
        if (DateTime.now().difference(quietSince) > _timing.carOffWindow) {
          return TripEnd.carOff;
        }
        await _notify(TripNotificationText.waitingForCar(vehicle));
      }
      final outcome = silent
          ? await _session.checkCar()
          : await _readings.readAndKeep();
      switch (outcome) {
        // Someone else is using the adapter, as from Developer tools; try
        // again after the interval.
        case StepRefused(refusal: Refusal.busy):
          break;
        case StepRefused(refusal: Refusal.vehicleRemoved):
          return TripEnd.noVehicle;
        case StepRefused() || StepFailed():
          lost = true;
        case StepDone(value: VehicleReading(reading: CarSilent())):
          silent = true;
        case StepDone(value: VehicleReading(reading: CarAwake())):
          silent = false;
          quietSince = null;
        case StepDone(value: VehicleReading(reading: CarAnswered())):
          silent = false;
          quietSince = null;
          run.sentReadings = true;
          await _notify(TripNotificationText.reading(vehicle, interval));
      }
      // Reconnecting doesn't wait.
      if (!lost) await run.sleep(interval);
    }
    return TripEnd.stopped;
  }

  /// Tells the receiver the car disconnected, if readings went out.
  Future<void> _close(_TripRun run, Vehicle vehicle) async {
    if (!run.sentReadings) return;
    await _notify(TripNotificationText.ending);
    await _readings.close(vehicle, wait: _timing.finalDeliveryWait);
  }

  /// Closes the trip. Each step runs even if one before it fails, so the
  /// adapter is let go and the service stopped however the trip ended.
  Future<void> _finish(_TripRun run, TripEnd end, {Vehicle? vehicle}) async {
    state = const TripEnding();
    // Mark the end, but only after readings: a trip that never sent one,
    // like a stereo waking with the car parked, has nothing to close.
    if (vehicle != null) {
      await _guarded('Closing the trip', () => _close(run, vehicle));
    }
    if (_sessionState is! SessionIdle) {
      await _guarded('Disconnecting', _session.disconnect);
    }
    ref.read(adapterLogProvider).note('Trip ended: ${end.name}');
    await _guarded('Stopping the trip service', _gateway.stopService);
    _current = null;
    state = TripIdle(lastEnd: end);
  }

  /// Runs one step of ending a trip, reporting it if it fails.
  Future<void> _guarded(String step, Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (error, stack) {
      _report('$step failed', error, stack);
    }
  }

  /// Android started the service for a trip whose target can't be read,
  /// or can't be fetched. No trip will run on it, so it's stopped, unless
  /// a trip already is.
  void _refuse(Object error, StackTrace stack) {
    _report('Trip start not understood', error, stack);
    if (_current == null) {
      unawaited(_guarded('Stopping the trip service', _gateway.stopService));
    }
  }

  /// Nothing awaits a trip, so its failures are reported here: in the
  /// adapter log for the user, and as an error in the system log.
  void _report(String what, Object error, StackTrace stack) {
    ref.read(adapterLogProvider).note('$what: $error', warning: true);
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stack, library: 'trip'),
    );
  }

  Future<void> _notify(String text) => _gateway.updateNotification(text);
}
