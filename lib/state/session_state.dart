import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/bluetooth/bluetooth_gateway.dart';
import '../core/obd/elm327.dart';
import '../core/obd/obd_transport.dart';
import '../core/platform/permission_gateway.dart';
import '../core/profiles/signal_set.dart';
import '../core/profiles/stored_profile.dart';
import '../core/session/car_reading.dart';
import '../core/session/car_state.dart';
import '../core/vehicles/vehicle.dart';
import 'infrastructure.dart';
import 'permissions_state.dart';
import 'session_outcome.dart';
import 'settings_state.dart';

export 'session_outcome.dart';

/// One connection, from the moment it's asked for until it's closed: the
/// vehicle it's for, the adapter connection once one is asked for, and
/// the adapter on it once it opens. The session holds at most one, and
/// only it can close it; a step that finds another one current, or none,
/// knows the connection it began with is gone.
class _Connection {
  _Connection(this.vehicleId);

  final String vehicleId;

  AdapterConnection? _adapter;
  Elm327? _elm;

  /// Whether connecting finished: the car was asked, and the session is
  /// connected through [elm].
  bool _live = false;

  /// The adapter, once the connection is live; null while it's being made.
  Elm327? get live => _live ? _elm : null;

  void asked(AdapterConnection adapter) => _adapter = adapter;
  void opened(Elm327 elm) => _elm = elm;
  void connected() => _live = true;

  /// Closes it at whatever stage: a connect still under way stops, and a
  /// command waiting on the adapter fails at once, as disconnected.
  Future<void> close() async {
    await _elm?.dispose();
    await _adapter?.close();
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

/// The connection to an adapter, used by trips and by Developer tools. It
/// only talks to the car; what's read goes on through `ReadingKeeper`.
class SessionController extends Notifier<SessionState> {
  /// The connection being made, or made; see [_Connection].
  _Connection? _connection;

  bool _isCurrent(_Connection connection) => identical(_connection, connection);

  @override
  SessionState build() {
    ref.onDispose(() => _connection?.close());
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
  ///
  /// The session is taken before anything is awaited, so a second connect
  /// meanwhile is refused as in use. A disconnect while connecting abandons
  /// the attempt.
  Future<ConnectResult> connect(Vehicle vehicle) async {
    switch (state) {
      case final SessionConnected live when live.vehicleId == vehicle.id:
        return StepDone(live);
      case SessionConnecting() || SessionConnected():
        return const StepRefused(Refusal.inUse);
      case SessionIdle():
        break;
    }
    final address = vehicle.adapter?.address;
    if (address == null) return const StepRefused(Refusal.noAdapter);
    final connection = _Connection(vehicle.id);
    _connection = connection;
    state = SessionConnecting(vehicle.id);
    // Disconnected while connecting: the disconnect already set the state,
    // and closed whatever was open.
    const abandoned = StepFailed<SessionConnected>(
      ConnectionProblem.disconnected,
    );
    final log = ref.read(adapterLogProvider);
    final granted = await ref
        .read(permissionsProvider.notifier)
        .check(AppPermission.bluetooth);
    if (!_isCurrent(connection)) return abandoned;
    if (!granted) return _lost(ConnectionProblem.permissionDenied);
    final adapter = ref.read(bluetoothGatewayProvider).connect(address);
    connection.asked(adapter);
    final ObdTransport transport;
    try {
      transport = await adapter.opened;
    } on PlatformException {
      if (!_isCurrent(connection)) return abandoned;
      log.note('Couldn\'t connect to the adapter', warning: true);
      return _lost(ConnectionProblem.connectFailed);
    }
    // Closed meanwhile, so the disconnect closed the adapter connection.
    if (!_isCurrent(connection)) return abandoned;
    final elm = Elm327(transport, log: log.exchange);
    connection.opened(elm);
    try {
      final version = await elm.initialize();
      final car = await _askCar(elm);
      if (!_isCurrent(connection)) return abandoned;
      connection.connected();
      final live = SessionConnected(
        vehicleId: vehicle.id,
        connectedAt: DateTime.now(),
        adapterVersion: version,
        supportedPids: car.supportedPids,
        carState: car.carState,
      );
      state = live;
      return StepDone(live);
    } on ElmException catch (e) {
      if (!_isCurrent(connection)) return abandoned;
      return StepFailed(await _failed(connection, e));
    }
  }

  /// Asks the car again whether it answers, e.g. after the ignition was off.
  Future<ReadOutcome> checkCar() => _withVehicle(
    (vehicle, connection) => _exclusive(connection, (session, elm) async {
      final car = await _askCar(elm);
      _update(
        (live) => live.copyWith(
          carState: car.carState,
          supportedPids: car.supportedPids,
        ),
      );
      return VehicleReading(vehicle, switch (car.carState) {
        CarState.off => const CarSilent(),
        final carState => CarAwake(carState),
      });
    }),
  );

  /// Reads the vehicle's chosen values. The vehicle, the values it sends
  /// and its profile are worked out once, before the adapter is taken.
  Future<ReadOutcome> read() => _withVehicle((vehicle, connection) async {
    final log = ref.read(adapterLogProvider);
    final profile = await _profileFor(vehicle.id);
    // With the profile loaded, its values are among the ones on offer.
    final sent = ref.read(vehicleValuesProvider(vehicle.id))?.sent;
    if (sent == null) return const StepRefused(Refusal.vehicleRemoved);
    final outcome = await _exclusive(
      connection,
      (session, elm) async => VehicleReading(
        vehicle,
        await readCar(
          elm,
          keys: sent,
          profile: profile,
          modelYear: vehicle.modelYear,
          supportedPids: session.supportedPids,
        ),
      ),
    );
    switch (outcome) {
      case StepDone(value: VehicleReading(reading: CarSilent())):
        // The ignition went off; the adapter is still there.
        log.note('Car stopped answering', warning: true);
        _update((live) => live.copyWith(carState: CarState.off));
      case StepDone(value: VehicleReading(reading: CarAwake(:final carState))):
        log.note('Nothing to send: the car reported none of the values');
        _update((live) => live.copyWith(carState: carState));
      case StepDone(
        value: VehicleReading(
          reading: CarAnswered(:final values, :final carState),
        ),
      ):
        values.forEach(log.value);
        _update((live) => live.copyWith(carState: carState));
      case StepRefused() || StepFailed():
        break;
    }
    return outcome;
  });

  /// Runs [ask] for the vehicle the session is connected to, on that
  /// connection, or says why there's none to ask for. [ask] hands the
  /// connection to [_exclusive], which refuses if it's no longer current,
  /// so a read can't move to a connection made meanwhile.
  Future<ReadOutcome> _withVehicle(
    Future<ReadOutcome> Function(Vehicle vehicle, _Connection connection) ask,
  ) async {
    final connection = _connection;
    if (connection == null || connection.live == null) {
      return const StepRefused(Refusal.notConnected);
    }
    final vehicle = ref.read(vehicleProvider(connection.vehicleId));
    if (vehicle == null) return const StepRefused(Refusal.vehicleRemoved);
    return ask(vehicle, connection);
  }

  /// The vehicle's profile, if it loaded. One that can't be read reads
  /// nothing: standard values still go out, and the vehicle's page shows
  /// the problem.
  Future<SignalSet?> _profileFor(String vehicleId) async =>
      switch (await ref.read(vehicleProfileProvider(vehicleId).future)) {
        LoadedProfile(:final signals) => signals,
        NoProfile() || UnreadableProfile() => null,
      };

  /// Sends the raw commands typed in [input], separated by commas or
  /// spaces; replies show up in the log. AT commands can change settings
  /// the app relies on, so the adapter is reset afterwards.
  ///
  /// Says in the log, where their replies would have been, when they
  /// couldn't go out. Nothing typed is nothing to send, and done.
  Future<StepOutcome<void>> sendRaw(String input) async {
    final commands = [
      for (final command in input.split(RegExp(r'[,\s]+')))
        if (command.isNotEmpty) command.toUpperCase(),
    ];
    if (commands.isEmpty) return const StepDone(null);
    final outcome = await _exclusive(_connection, (session, elm) async {
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

  /// Leaves the session idle at once, then closes the connection: nothing
  /// sees a connected session whose link is gone.
  Future<void> disconnect() async {
    final connection = _connection;
    _connection = null;
    state = const SessionIdle();
    ref.read(adapterLogProvider).note('Disconnected');
    await connection?.close();
  }

  /// Asks the car which standard values it supports, which also shows
  /// whether it answers. Off, it supports none.
  Future<({CarState carState, Set<int> supportedPids})> _askCar(
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
      return (carState: CarState.off, supportedPids: const <int>{});
    }
  }

  /// Runs [operation] on [connection]'s adapter, one at a time, if it's
  /// still the current, live connection. Busy is cleared however it ends.
  ///
  /// Everything after the operation concerns [connection] only: if the
  /// session was disconnected meanwhile, or another connection made, the
  /// failure is the disconnect's, and nothing about the present session
  /// changes.
  Future<StepOutcome<T>> _exclusive<T>(
    _Connection? connection,
    Future<T> Function(SessionConnected session, Elm327 elm) operation,
  ) async {
    if (connection == null || !_isCurrent(connection)) {
      return const StepRefused(Refusal.notConnected);
    }
    final elm = connection.live;
    final session = state;
    // A live, current connection is a connected session: connect makes
    // both so together.
    if (elm == null || session is! SessionConnected) {
      return const StepRefused(Refusal.notConnected);
    }
    if (session.busy) return const StepRefused(Refusal.busy);
    state = session.copyWith(busy: true);
    try {
      return StepDone(await operation(session, elm));
    } on ElmException catch (e) {
      if (!_isCurrent(connection)) {
        return const StepFailed(ConnectionProblem.disconnected);
      }
      return StepFailed(await _failed(connection, e));
    } finally {
      if (_isCurrent(connection)) {
        _update((live) => live.copyWith(busy: false));
      }
    }
  }

  /// Applies [change] to the live session, if it's still live.
  void _update(SessionConnected Function(SessionConnected live) change) {
    if (state case final SessionConnected live) state = change(live);
  }

  /// The current connection attempt failed before its transport opened.
  StepOutcome<T> _lost<T>(ConnectionProblem problem) {
    _connection = null;
    state = SessionIdle(problem: problem);
    return StepFailed(problem);
  }

  /// Notes an adapter failure on the current [connection], leaves the
  /// session idle, and closes it.
  Future<ConnectionProblem> _failed(
    _Connection connection,
    ElmException error,
  ) async {
    _connection = null;
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
    await connection.close();
    return problem;
  }
}
