import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/bluetooth/bluetooth_gateway.dart';
import '../core/obd/elm327.dart';
import '../core/platform/permission_gateway.dart';
import '../core/readings/readings.dart';
import '../core/session/car_state.dart';
import '../core/vehicles/vehicle.dart';
import 'infrastructure.dart';
import 'last_values_state.dart';
import 'permissions_state.dart';
import 'settings_state.dart';

enum SessionPhase { idle, connecting, connected }

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

/// A live connection to a vehicle's adapter. For now it's started by hand
/// from the developer tools; the background service will drive it later.
@immutable
class SessionState {
  const SessionState({
    this.phase = SessionPhase.idle,
    this.vehicleId,
    this.connectedAt,
    this.carState = CarState.unknown,
    this.supportedPids = const {},
    this.adapterVersion,
    this.problem,
    this.busy = false,
  });

  final SessionPhase phase;
  final String? vehicleId;
  final DateTime? connectedAt;
  final CarState carState;
  final Set<int> supportedPids;
  final String? adapterVersion;

  /// Why the last connection attempt or operation failed.
  final SessionProblem? problem;

  /// An operation is running on the adapter.
  final bool busy;

  bool get isConnected => phase == SessionPhase.connected;

  SessionState copyWith({
    SessionPhase? phase,
    CarState? carState,
    Set<int>? supportedPids,
    String? adapterVersion,
    SessionProblem? problem,
    bool clearProblem = false,
    bool? busy,
  }) => SessionState(
    phase: phase ?? this.phase,
    vehicleId: vehicleId,
    connectedAt: connectedAt,
    carState: carState ?? this.carState,
    supportedPids: supportedPids ?? this.supportedPids,
    adapterVersion: adapterVersion ?? this.adapterVersion,
    problem: clearProblem ? null : (problem ?? this.problem),
    busy: busy ?? this.busy,
  );
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

class SessionController extends Notifier<SessionState> {
  ClosableTransport? _transport;
  Elm327? _elm;

  @override
  SessionState build() {
    ref.onDispose(_close);
    return const SessionState();
  }

  /// Connects to the vehicle's adapter and checks whether the car answers.
  ///
  /// With [askPermission] false (during a trip, with no screen to ask on),
  /// a missing Bluetooth permission fails instead of prompting.
  Future<void> connect(Vehicle vehicle, {bool askPermission = true}) async {
    final address = vehicle.adapterAddress;
    if (address == null || state.phase != SessionPhase.idle) return;
    final log = ref.read(adapterLogProvider);
    final granted = askPermission
        ? await ref
              .read(permissionsProvider.notifier)
              .request(AppPermission.bluetooth)
        : await ref
              .read(permissionGatewayProvider)
              .isGranted(AppPermission.bluetooth);
    if (!granted) {
      state = const SessionState(problem: SessionProblem.permissionDenied);
      return;
    }
    state = SessionState(phase: SessionPhase.connecting, vehicleId: vehicle.id);
    try {
      final transport = await ref
          .read(bluetoothGatewayProvider)
          .connect(address);
      final elm = Elm327(transport, log: log.exchange);
      _transport = transport;
      _elm = elm;
      final version = await elm.initialize();
      final now = DateTime.now();
      state = SessionState(
        phase: SessionPhase.connected,
        vehicleId: vehicle.id,
        connectedAt: now,
        adapterVersion: version,
        busy: true,
      );
      await ref.read(appSettingsProvider.notifier).markSeen(vehicle.id, now);
      await _checkCar(elm);
    } on PlatformException {
      await _close();
      log.note('Couldn\'t connect to the adapter', warning: true);
      state = const SessionState(problem: SessionProblem.connectFailed);
    } on ElmException catch (e) {
      await _fail(e);
    }
  }

  /// Asks the car again whether it answers, e.g. after the ignition was off.
  Future<void> checkCar() async {
    final elm = _elm;
    if (elm == null || state.busy) return;
    state = state.copyWith(busy: true);
    try {
      await _checkCar(elm);
    } on ElmException catch (e) {
      await _fail(e);
    }
  }

  Future<void> _checkCar(Elm327 elm) async {
    final log = ref.read(adapterLogProvider);
    try {
      final supported = await elm.supportedPids();
      log.note('Car answered, ${supported.length} values supported');
      state = state.copyWith(
        carState: CarState.ignitionOn,
        supportedPids: supported,
        busy: false,
      );
    } on ElmException catch (e) {
      if (e.error != ElmError.unableToConnect) rethrow;
      log.note('Car didn\'t answer: ignition off?', warning: true);
      state = state.copyWith(carState: CarState.off, busy: false);
    }
  }

  /// Reads the vehicle's chosen values and sends them to the webhook.
  /// Returns what was read: empty if the car reported nothing or stopped
  /// answering, null if the session couldn't read at all.
  Future<Map<String, double>?> readAndSend() async {
    final elm = _elm;
    final vehicleId = state.vehicleId;
    if (elm == null || vehicleId == null || state.busy) return null;
    final vehicle = ref.read(vehicleProvider(vehicleId));
    if (vehicle == null) return null;
    final log = ref.read(adapterLogProvider);
    state = state.copyWith(busy: true, clearProblem: true);
    try {
      final profile = await ref.read(vehicleProfileProvider(vehicleId).future);
      final values = await readValues(
        elm,
        keys: keysToSend(vehicle, valueOptions(profile, vehicle.modelYear)),
        supportedPids: state.supportedPids,
        profile: profile,
        modelYear: vehicle.modelYear,
      );
      values.forEach(log.value);
      await ref
          .read(lastValuesProvider.notifier)
          .record(vehicleId, values, DateTime.now());
      // Values the adapter measures itself come back with the car switched
      // off too; without any from the car, make sure it still answers.
      if (values.keys.every((key) => key == batteryVoltageKey)) {
        await elm.requestPid(0x00);
      }
      // The engine's state needs the battery voltage, sent or not.
      final voltage =
          values[batteryVoltageKey] ?? await elm.readBatteryVoltage();
      final carState = carStateFrom({...values, batteryVoltageKey: ?voltage});
      state = state.copyWith(carState: carState, busy: false);
      if (values.isEmpty) {
        log.note('Nothing to send: the car reported none of the values');
        return values;
      }
      await ref
          .read(webhookSenderProvider)
          .send(
            device: vehicle.deviceId,
            values: values,
            connected: true,
            engineRunning: carState == CarState.engineRunning,
          );
      return values;
    } on ElmException catch (e) {
      // The car going quiet mid-read means the ignition went off; the
      // adapter is still there.
      if (e.error == ElmError.unableToConnect) {
        log.note('Car stopped answering', warning: true);
        state = state.copyWith(carState: CarState.off, busy: false);
        return const {};
      }
      await _fail(e);
      return null;
    }
  }

  /// Sends raw commands to the adapter; replies show up in the log. AT
  /// commands can change settings the app relies on, so the adapter is
  /// reset afterwards.
  Future<void> sendRaw(List<String> commands) async {
    final elm = _elm;
    if (elm == null || state.busy || commands.isEmpty) return;
    state = state.copyWith(busy: true);
    try {
      for (final command in commands) {
        try {
          await elm.send(command);
        } on ElmException catch (e) {
          if (e.error == ElmError.disconnected) rethrow;
        }
      }
      if (commands.any((c) => c.startsWith('AT'))) await elm.initialize();
      state = state.copyWith(busy: false);
    } on ElmException catch (e) {
      await _fail(e);
    }
  }

  Future<void> disconnect() async {
    await _close();
    ref.read(adapterLogProvider).note('Disconnected');
    state = const SessionState();
  }

  Future<void> _fail(ElmException error) async {
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
    state = SessionState(
      problem: dropped
          ? SessionProblem.disconnected
          : SessionProblem.adapterError,
    );
  }

  Future<void> _close() async {
    final transport = _transport;
    final elm = _elm;
    _transport = null;
    _elm = null;
    await elm?.dispose();
    try {
      await transport?.close();
    } on PlatformException {
      // Already gone.
    }
  }
}
