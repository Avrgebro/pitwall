import '../obd/elm327.dart';
import '../readings/unreported.dart';
import 'signal_set.dart';

/// Reads the signals in [signalSet] that apply to [modelYear] and returns
/// the values by payload key, and why any it asked for didn't come back. If [keys] is given, only signals with those
/// keys are decoded, and only the requests they need are sent. A key
/// several requests carry is read through the first; see
/// [SignalSet.readsFor].
///
/// Requests that need flow control are skipped on adapters that can't set
/// it, as [Elm327.initialize] found.
///
/// Always switches the adapter back to the default broadcast address, so
/// standard reads keep working afterwards.
Future<ValuesRead> readProfile(
  Elm327 elm,
  SignalSet signalSet,
  int modelYear, {
  Set<String>? keys,
}) async {
  bool wanted(ProfileSignal signal) =>
      keys?.contains(signal.metric.key) ?? true;
  final values = <String, double>{};
  final unreported = <String, Unreported>{};
  void missing(Iterable<ProfileSignal> signals, Unreported why) {
    for (final signal in signals) {
      unreported[signal.metric.key] = why;
    }
  }

  try {
    for (final (:command, :signals) in signalSet.readsFor(
      modelYear,
      flowControl: elm.setsFlowControl,
    )) {
      final read = signals.where(wanted).toList();
      if (read.isEmpty) continue;
      await elm.setTarget(command.header, receive: command.receive);
      final List<List<int>> replies;
      try {
        replies = await elm.request(command.service, command.id);
      } on ElmException catch (e) {
        // One module's bus error shouldn't stop the others.
        if (e.error != ElmError.busError) rethrow;
        missing(read, Unreported.noAnswer);
        continue;
      }
      if (replies.isEmpty) {
        missing(read, Unreported.noAnswer);
        continue;
      }
      final reply = replies.first;
      for (final signal in read) {
        switch (signal.decode(reply)) {
          case final value?:
            values[signal.metric.key] = value;
          case null when !signal.format.fits(reply):
            missing([signal], Unreported.notInReply);
          case null:
            missing([signal], Unreported.unavailable);
        }
      }
    }
  } finally {
    if (!elm.isClosed) await elm.setTarget(null);
  }
  return (values: values, unreported: unreported);
}
