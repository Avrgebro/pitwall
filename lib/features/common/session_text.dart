import '../../state/session_state.dart';
import '../../state/trip_state.dart';

/// Why a trip ended, in words.
extension TripEndText on TripEnd {
  String get label => switch (this) {
    TripEnd.stopped => 'stopped',
    TripEnd.noVehicle => 'no vehicle has an adapter',
    TripEnd.permissionMissing => 'Nearby devices permission missing',
    TripEnd.adapterNotFound => 'the adapter didn\'t answer',
    TripEnd.carOff => 'the car stopped answering',
    TripEnd.adapterLost => 'the adapter dropped',
    TripEnd.failed => 'something went wrong (see the log)',
  };
}

/// Why the session isn't connected, in words.
extension ConnectionProblemText on ConnectionProblem {
  String get label => switch (this) {
    ConnectionProblem.permissionDenied =>
      'Pitwall needs the Nearby devices permission to connect.',
    ConnectionProblem.connectFailed =>
      'Couldn\'t reach the adapter. Is it plugged in and the ignition on?',
    ConnectionProblem.disconnected => 'The adapter disconnected.',
    ConnectionProblem.adapterError =>
      'The adapter stopped answering. Connect again.',
  };
}
