import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/bluetooth/bluetooth_gateway.dart';
import '../core/obd/elm327.dart';
import '../core/profiles/signal_set.dart';
import '../core/platform/permission_gateway.dart';
import '../core/session/car_reading.dart';
import '../core/session/car_state.dart';
import '../core/vehicles/vehicle.dart';
import 'infrastructure.dart';
import 'permissions_state.dart';
import 'settings_state.dart';

/// Why the session isn't connected: the connection was tried and failed,
/// or it was lost.
enum ConnectionProblem {
  /// Bluetooth permission isn't granted.
  permissionDenied,

  /// The adapter couldn't be reached over Bluetooth.
  connectFailed,

  /// The adapter dropped the connection.
  disconnected,

  /// The adapter reported an error or stopped answering.
  adapterError,
}

/// Why the session didn't do what was asked, without trying.
enum Refusal {
  /// The vehicle has no adapter chosen.
  noAdapter,

  /// Another connection is being made or is open.
  inUse,

  /// Not connected, so nothing could be asked.
  notConnected,

  /// Another operation is running on the adapter.
  busy,

  /// The connected vehicle was deleted, so there's nothing to read for.
  vehicleRemoved,
}

/// How a step on the session ended: done, refused without trying, or
/// failed, which leaves the session idle.
sealed class StepOutcome<T> {
  const StepOutcome();
}

final class StepDone<T> extends StepOutcome<T> {
  const StepDone(this.value);

  final T value;
}

final class StepRefused<T> extends StepOutcome<T> {
  const StepRefused(this.refusal);

  final Refusal refusal;
}

final class StepFailed<T> extends StepOutcome<T> {
  const StepFailed(this.problem);

  final ConnectionProblem problem;
}

/// How a connection attempt ended: done with the live session.
typedef ConnectResult = StepOutcome<SessionConnected>;

/// How asking the car something ended: done with what it said.
typedef ReadOutcome = StepOutcome<CarReading>;

/// A connection to a vehicle's adapter: none, being made, or live. Each
/// stage carries only what's known in it.
@immutable
sealed class SessionState {
  const SessionState();
}

final class SessionIdle extends SessionState {
  const SessionIdle({this.problem});

  /// Why the last connection failed or was lost, if it was.
  final ConnectionProblem? problem;
}

final class SessionConnecting extends SessionState {
  const SessionConnecting(this.vehicleId);

  final String vehicleId;
}

final class SessionConnected extends SessionState {
  const SessionConnected({
    required this.vehicleId,
    required this.connectedAt,
    this.adapterVersion,
    this.supportedPids = const {},
    this.carState = CarState.unknown,
    this.busy = false,
  });

  final String vehicleId;
  final DateTime connectedAt;
  final String? adapterVersion;
  final Set<int> supportedPids;
  final CarState carState;

  /// An operation is running on the adapter.
  final bool busy;

  SessionConnected copyWith({
    Set<int>? supportedPids,
    CarState? carState,
    bool? busy,
  }) => SessionConnected(
    vehicleId: vehicleId,
    connectedAt: connectedAt,
    adapterVersion: adapterVersion,
    supportedPids: supportedPids ?? this.supportedPids,
    carState: carState ?? this.carState,
    busy: busy ?? this.busy,
  );
}

/// The open connection: the transport and the adapter on it, always
/// together.
class _Link {
  const _Link(this.transport, this.elm);

  final ClosableTransport transport;
  final Elm327 elm;

  Future<void> close() async {
    await elm.dispose();
    try {
      await transport.close();
    } on PlatformException {
      // Already gone.
    }
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

/// The connection to an adapter, used by trips and by Developer tools. It
/// only talks to the car; what's read goes on through `ReadingKeeper`.
class SessionController extends Notifier<SessionState> {
  /// Set only once the adapter has initialised.
  _Link? _link;

  @override
  SessionState build() {
    ref.onDispose(_close);
    // A connection means the car was seen, however it was made.
    listenSelf((previous, next) {
      if (next is SessionConnected && previous is! SessionConnected) {
        unawaited(
          ref
              .read(appSettingsProvider.notifier)
              .markSeen(next.vehicleId, next.connectedAt),
        );
      }
    });
    // A connection is to one vehicle; once it's deleted, the connection
    // has nothing left to do.
    ref.listen(appSettingsProvider, (_, settings) {
      if ((state, settings.value)
          case (SessionConnected(:final vehicleId), final settings?)
          when settings.vehicleById(vehicleId) == null) {
        unawaited(disconnect());
      }
    });
    return const SessionIdle();
  }

  /// Connects to the vehicle's adapter and checks whether the car answers.
  ///
  /// Only checks the Bluetooth permission: a screen asks for it first, and
  /// a trip has no screen to ask on.
  Future<ConnectResult> connect(Vehicle vehicle) async {
    final address = vehicle.adapterAddress;
    switch (state) {
      case final SessionConnected live when live.vehicleId == vehicle.id:
        return StepDone(live);
      case SessionConnecting() || SessionConnected():
        return const StepRefused(Refusal.inUse);
      case SessionIdle() when address == null:
        return const StepRefused(Refusal.noAdapter);
      case SessionIdle():
        break;
    }
    final log = ref.read(adapterLogProvider);
    final granted = await ref
        .read(permissionsProvider.notifier)
        .check(AppPermission.bluetooth);
    if (!granted) return _lost(ConnectionProblem.permissionDenied);
    state = SessionConnecting(vehicle.id);
    final ClosableTransport transport;
    try {
      transport = await ref.read(bluetoothGatewayProvider).connect(address!);
    } on PlatformException {
      log.note('Couldn\'t connect to the adapter', warning: true);
      return _lost(ConnectionProblem.connectFailed);
    }
    final link = _Link(transport, Elm327(transport, log: log.exchange));
    try {
      final version = await link.elm.initialize();
      final car = await _askCar(link.elm);
      _link = link;
      final live = SessionConnected(
        vehicleId: vehicle.id,
        connectedAt: DateTime.now(),
        adapterVersion: version,
        supportedPids: car.supportedPids ?? const {},
        carState: car.carState,
      );
      state = live;
      return StepDone(live);
    } on ElmException catch (e) {
      await link.close();
      return StepFailed(_failed(e));
    }
  }

  /// Asks the car again whether it answers, e.g. after the ignition was off.
  Future<ReadOutcome> checkCar() => _exclusive((session, elm) async {
    final car = await _askCar(elm);
    _update(
      (live) => live.copyWith(
        carState: car.carState,
        supportedPids: car.supportedPids,
      ),
    );
    return switch (car.carState) {
      CarState.off => const CarSilent(),
      final carState => CarAwake(carState),
    };
  });

  /// Reads the vehicle's chosen values.
  Future<ReadOutcome> read() async {
    final Vehicle vehicle;
    switch (state) {
      case SessionConnected(:final vehicleId):
        final found = ref.read(vehicleProvider(vehicleId));
        if (found == null) return const StepRefused(Refusal.vehicleRemoved);
        vehicle = found;
      case SessionIdle() || SessionConnecting():
        return const StepRefused(Refusal.notConnected);
    }
    final log = ref.read(adapterLogProvider);
    final profile = await _profileFor(vehicle.id);
    final outcome = await _exclusive(
      (session, elm) => readCar(
        elm,
        vehicle: vehicle,
        profile: profile,
        supportedPids: session.supportedPids,
      ),
    );
    switch (outcome) {
      case StepDone(value: CarSilent()):
        // The ignition went off; the adapter is still there.
        log.note('Car stopped answering', warning: true);
        _update((live) => live.copyWith(carState: CarState.off));
      case StepDone(value: CarAwake(:final carState)):
        log.note('Nothing to send: the car reported none of the values');
        _update((live) => live.copyWith(carState: carState));
      case StepDone(value: CarAnswered(:final values, :final carState)):
        values.forEach(log.value);
        _update((live) => live.copyWith(carState: carState));
      case StepRefused() || StepFailed():
        break;
    }
    return outcome;
  }

  /// The vehicle's profile, if it loaded. One that can't be read reads
  /// nothing: standard values still go out, and the vehicle's page shows
  /// the problem.
  Future<SignalSet?> _profileFor(String vehicleId) async =>
      (await ref.read(vehicleProfileProvider(vehicleId).future)).signals;

  /// Sends raw commands to the adapter; replies show up in the log. AT
  /// commands can change settings the app relies on, so the adapter is
  /// reset afterwards.
  ///
  /// Says in the log, where their replies would have been, when they
  /// couldn't go out.
  Future<StepOutcome<void>> sendRaw(List<String> commands) async {
    final outcome = await _exclusive((session, elm) async {
      for (final command in commands) {
        try {
          await elm.send(command);
        } on ElmException catch (e) {
          if (e.error == ElmError.disconnected) rethrow;
        }
      }
      if (commands.any((c) => c.startsWith('AT'))) await elm.initialize();
    });
    final log = ref.read(adapterLogProvider);
    switch (outcome) {
      case StepRefused(refusal: Refusal.busy):
        log.note('Not sent: the adapter is busy, as with a trip\'s reading');
      case StepRefused():
        log.note('Not sent: not connected');
      case StepDone() || StepFailed():
        // Failures on the adapter are logged as they happen.
        break;
    }
    return outcome;
  }

  Future<void> disconnect() async {
    await _close();
    ref.read(adapterLogProvider).note('Disconnected');
    state = const SessionIdle();
  }

  /// Asks the car which standard values it supports, which also shows
  /// whether it answers. Off, it keeps no supported values.
  Future<({CarState carState, Set<int>? supportedPids})> _askCar(
    Elm327 elm,
  ) async {
    final log = ref.read(adapterLogProvider);
    try {
      final supported = await elm.supportedPids();
      log.note('Car answered, ${supported.length} values supported');
      return (carState: CarState.ignitionOn, supportedPids: supported);
    } on ElmException catch (e) {
      if (e.error != ElmError.unableToConnect) rethrow;
      log.note('Car didn\'t answer: ignition off?', warning: true);
      return (carState: CarState.off, supportedPids: null);
    }
  }

  /// Runs [operation] on the adapter, one at a time. Busy is cleared
  /// however it ends.
  Future<StepOutcome<T>> _exclusive<T>(
    Future<T> Function(SessionConnected session, Elm327 elm) operation,
  ) async {
    final link = _link;
    final session = state;
    if (link == null || session is! SessionConnected) {
      return const StepRefused(Refusal.notConnected);
    }
    if (session.busy) return const StepRefused(Refusal.busy);
    state = session.copyWith(busy: true);
    try {
      return StepDone(await operation(session, link.elm));
    } on ElmException catch (e) {
      await _close();
      return StepFailed(_failed(e));
    } finally {
      _update((live) => live.copyWith(busy: false));
    }
  }

  /// Applies [change] to the live session, if it's still live.
  void _update(SessionConnected Function(SessionConnected live) change) {
    if (state case final SessionConnected live) state = change(live);
  }

  StepOutcome<T> _lost<T>(ConnectionProblem problem) {
    state = SessionIdle(problem: problem);
    return StepFailed(problem);
  }

  /// Notes an adapter failure and leaves the session idle. The link is
  /// closed by then.
  ConnectionProblem _failed(ElmException error) {
    final dropped = error.error == ElmError.disconnected;
    ref
        .read(adapterLogProvider)
        .note(
          dropped
              ? 'The adapter disconnected'
              : 'Adapter error: ${error.error.name} on ${error.command}',
          warning: true,
        );
    final problem = dropped
        ? ConnectionProblem.disconnected
        : ConnectionProblem.adapterError;
    state = SessionIdle(problem: problem);
    return problem;
  }

  Future<void> _close() async {
    final link = _link;
    _link = null;
    await link?.close();
  }
}
