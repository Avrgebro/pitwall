import '../obd/elm327.dart';
import 'signal_set.dart';

/// Profile keys that replace standard keys measuring the same thing. A
/// profile with fuel in litres means the standard fuel percent can't be
/// trusted on that car.
const replacedStandardKeys = {
  'fuel_level_l': {'fuel_level_pct'},
};

/// Reads the signals in [signalSet] that apply to [modelYear] and returns
/// the values by payload key. If [keys] is given, only signals with those
/// keys are decoded, and only the requests they need are sent. When several
/// signals share a key, the first one with a value wins.
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
    for (final command in signalSet.commandsFor(modelYear)) {
      if (!command.signals.any(wanted)) continue;
      await elm.setTarget(command.header, receive: command.receive);
      final List<List<int>> replies;
      try {
        replies = await elm.request(command.service, command.id);
      } on ElmException catch (e) {
        // One module's bus error shouldn't stop the others.
        if (e.error == ElmError.busError) continue;
        rethrow;
      }
      if (replies.isEmpty) continue;
      for (final signal in command.signals.where(wanted)) {
        final value = signal.decode(replies.first);
        if (value != null) values.putIfAbsent(signal.key, () => value);
      }
    }
  } finally {
    if (!elm.isClosed) await elm.setTarget(null);
  }
  return values;
}

/// Combines standard values with profile values. Profile values win, and
/// remove standard values they replace (see [replacedStandardKeys]).
Map<String, double> mergeValues(
  Map<String, double> standard,
  Map<String, double> profile,
) {
  final replaced = {
    for (final key in profile.keys) ...?replacedStandardKeys[key],
  };
  return {
    for (final entry in standard.entries)
      if (!replaced.contains(entry.key)) entry.key: entry.value,
    ...profile,
  };
}
