import '../obd/elm327.dart';
import 'signal_set.dart';

/// Reads the signals in [signalSet] that apply to [modelYear] and returns
/// the values by payload key. If [keys] is given, only signals with those
/// keys are decoded, and only the requests they need are sent. A key
/// several requests carry is read through the first; see
/// [SignalSet.readsFor].
///
/// Requests that need flow control are skipped on adapters that can't set
/// it.
///
/// Always switches the adapter back to the default broadcast address, so
/// standard reads keep working afterwards.
Future<Map<String, double>> readProfile(
  Elm327 elm,
  SignalSet signalSet,
  int modelYear, {
  Set<String>? keys,
}) async {
  bool wanted(ProfileSignal signal) => keys?.contains(signal.key) ?? true;
  final values = <String, double>{};
  try {
    for (final (:command, :signals) in signalSet.readsFor(modelYear)) {
      final read = signals.where(wanted).toList();
      if (read.isEmpty) continue;
      await elm.setTarget(command.header, receive: command.receive);
      // Without flow control its reply comes back cut short, so asking
      // would only take time.
      if (command.needsFlowControl && !elm.setsFlowControl) continue;
      final List<List<int>> replies;
      try {
        replies = await elm.request(command.service, command.id);
      } on ElmException catch (e) {
        // One module's bus error shouldn't stop the others.
        if (e.error == ElmError.busError) continue;
        rethrow;
      }
      if (replies.isEmpty) continue;
      for (final signal in read) {
        if (signal.decode(replies.first) case final value?) {
          values[signal.key] = value;
        }
      }
    }
  } finally {
    if (!elm.isClosed) await elm.setTarget(null);
  }
  return values;
}
