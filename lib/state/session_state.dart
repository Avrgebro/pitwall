import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/bluetooth/bluetooth_gateway.dart';
import '../core/obd/elm327.dart';
import '../core/profiles/signal_set.dart';
import '../core/platform/permission_gateway.dart';
import '../core/readings/readings.dart';
import '../core/session/car_reading.dart';
import '../core/session/car_state.dart';
import '../core/settings/settings_store.dart';
import '../core/vehicles/vehicle.dart';
import 'infrastructure.dart';
import 'last_values_state.dart';
import 'permissions_state.dart';
import 'settings_state.dart';

enum SessionProblem {
  /// Bluetooth permission wasn't granted.
  permissionDenied,

  /// The adapter couldn't be reached over Bluetooth.
  connectFailed,

  /// The adapter dropped the connection.
  disconnected,

  /// The adapter reported an error or stopped answering.
  adapterError,
}

/// A connection to a vehicle's adapter: none, being made, or live. Each
/// stage carries only what's known in it.
@immutable
sealed class SessionState {
  const SessionState();

  /// The vehicle being connected to or connected, if any.
  String? get vehicleId => null;

  bool get isConnected => this is SessionConnected;

  /// This session if it's [id]'s, or idle otherwise: what a screen about
  /// one vehicle should show.
  SessionState forVehicle(String id) =>
      vehicleId == id ? this : const SessionIdle();
}

final class SessionIdle extends SessionState {
  const SessionIdle({this.problem});

  /// Why the last connection or operation failed, if it did.
  final SessionProblem? problem;
}

final class SessionConnecting extends SessionState {
  const SessionConnecting(this.vehicleId);

  @override
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

  @override
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

/// The connection to an adapter, used by trips and by Developer tools.
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
    return const SessionIdle();
  }

  /// Connects to the vehicle's adapter and checks whether the car answers.
  /// Returns null once connected, or why it couldn't; the state says the
  /// same.
  ///
  /// With [askPermission] false (during a trip, with no screen to ask on),
  /// a missing Bluetooth permission fails instead of prompting.
  Future<SessionProblem?> connect(
    Vehicle vehicle, {
    bool askPermission = true,
  }) async {
    final address = vehicle.adapterAddress;
    if (state is! SessionIdle || address == null) {
      return state is SessionConnected && state.vehicleId == vehicle.id
          ? null
          : SessionProblem.connectFailed;
    }
    final log = ref.read(adapterLogProvider);
    final granted = askPermission
        ? await ref
              .read(permissionsProvider.notifier)
              .request(AppPermission.bluetooth)
        : await ref
              .read(permissionGatewayProvider)
              .isGranted(AppPermission.bluetooth);
    if (!granted) {
      state = const SessionIdle(problem: SessionProblem.permissionDenied);
      return SessionProblem.permissionDenied;
    }
    state = SessionConnecting(vehicle.id);
    final ClosableTransport transport;
    try {
      transport = await ref.read(bluetoothGatewayProvider).connect(address);
    } on PlatformException {
      log.note('Couldn\'t connect to the adapter', warning: true);
      state = const SessionIdle(problem: SessionProblem.connectFailed);
      return SessionProblem.connectFailed;
    }
    final link = _Link(transport, Elm327(transport, log: log.exchange));
    try {
      final version = await link.elm.initialize();
      _link = link;
      state = SessionConnected(
        vehicleId: vehicle.id,
        connectedAt: DateTime.now(),
        adapterVersion: version,
      );
    } on ElmException catch (e) {
      await link.close();
      return _failed(e);
    }
    await checkCar();
    return switch (state) {
      SessionIdle(:final problem) => problem ?? SessionProblem.adapterError,
      _ => null,
    };
  }

  /// Asks the car again whether it answers, e.g. after the ignition was off.
  Future<void> checkCar() => _exclusive((session, elm) async {
    final log = ref.read(adapterLogProvider);
    try {
      final supported = await elm.supportedPids();
      log.note('Car answered, ${supported.length} values supported');
      _update(
        (live) => live.copyWith(
          carState: CarState.ignitionOn,
          supportedPids: supported,
        ),
      );
    } on ElmException catch (e) {
      if (e.error != ElmError.unableToConnect) rethrow;
      log.note('Car didn\'t answer: ignition off?', warning: true);
      _update((live) => live.copyWith(carState: CarState.off));
    }
  });

  /// Reads the vehicle's chosen values and sends them to the webhook.
  /// Returns what the car said, or null if the session couldn't read; the
  /// state then says why.
  Future<CarReading?> readAndSend() =>
      _exclusive<CarReading?>((session, elm) async {
        final vehicle = ref.read(vehicleProvider(session.vehicleId));
        if (vehicle == null) return null;
        final log = ref.read(adapterLogProvider);
        final profile = await _profileFor(vehicle.id);
        final reading = await readCar(
          elm,
          keys: keysToSend(vehicle, valueOptions(profile, vehicle.modelYear)),
          supportedPids: session.supportedPids,
          profile: profile,
          modelYear: vehicle.modelYear,
        );
        switch (reading) {
          case CarSilent():
            // The ignition went off; the adapter is still there.
            log.note('Car stopped answering', warning: true);
            _update((live) => live.copyWith(carState: CarState.off));
          case CarAnswered(:final values, :final carState):
            values.forEach(log.value);
            _update((live) => live.copyWith(carState: carState));
            await ref
                .read(lastValuesProvider.notifier)
                .record(vehicle.id, values, DateTime.now());
            if (values.isEmpty) {
              log.note('Nothing to send: the car reported none of the values');
            } else {
              await ref
                  .read(webhookSenderProvider)
                  .send(
                    device: vehicle.deviceId,
                    values: values,
                    connected: true,
                    engineRunning: carState == CarState.engineRunning,
                  );
            }
        }
        return reading;
      });

  /// The vehicle's profile, or none if its file can't be read: standard
  /// values still go out, and the vehicle's page shows the problem.
  Future<SignalSet?> _profileFor(String vehicleId) async {
    try {
      return await ref.read(vehicleProfileProvider(vehicleId).future);
    } on ProfileUnreadableException {
      return null;
    }
  }

  /// Sends raw commands to the adapter; replies show up in the log. AT
  /// commands can change settings the app relies on, so the adapter is
  /// reset afterwards.
  Future<void> sendRaw(List<String> commands) async {
    if (commands.isEmpty) return;
    await _exclusive((session, elm) async {
      for (final command in commands) {
        try {
          await elm.send(command);
        } on ElmException catch (e) {
          if (e.error == ElmError.disconnected) rethrow;
        }
      }
      if (commands.any((c) => c.startsWith('AT'))) await elm.initialize();
    });
  }

  Future<void> disconnect() async {
    await _close();
    ref.read(adapterLogProvider).note('Disconnected');
    state = const SessionIdle();
  }

  /// Runs [operation] on the adapter, one at a time. Returns null when the
  /// session isn't connected or is busy, or the adapter failed; the state
  /// then says why.
  Future<T?> _exclusive<T>(
    Future<T> Function(SessionConnected session, Elm327 elm) operation,
  ) async {
    final link = _link;
    final session = state;
    if (link == null || session is! SessionConnected || session.busy) {
      return null;
    }
    state = session.copyWith(busy: true);
    try {
      final result = await operation(session, link.elm);
      _update((live) => live.copyWith(busy: false));
      return result;
    } on ElmException catch (e) {
      await _failed(e);
      return null;
    }
  }

  /// Applies [change] to the live session, if it's still live.
  void _update(SessionConnected Function(SessionConnected live) change) {
    if (state case final SessionConnected live) state = change(live);
  }

  Future<SessionProblem> _failed(ElmException error) async {
    await _close();
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
        ? SessionProblem.disconnected
        : SessionProblem.adapterError;
    state = SessionIdle(problem: problem);
    return problem;
  }

  Future<void> _close() async {
    final link = _link;
    _link = null;
    await link?.close();
  }
}
