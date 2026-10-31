import '../obd/elm327.dart';
import 'signal_set.dart';

/// Profile keys that replace standard keys measuring the same thing. A
/// profile with fuel in litres means the standard fuel percent can't be
/// trusted on that car.
const replacedStandardKeys = {
  'fuel_level_l': {'fuel_level_pct'},
};

/// Reads every signal in [signalSet] that applies to [modelYear] and returns
/// the values by payload key. When several signals share a key, the first
/// one with a value wins.
///
/// Always switches the adapter back to the default broadcast address, so
/// standard reads keep working afterwards.
Future<Map<String, double>> readProfile(
  Elm327 elm,
  SignalSet signalSet,
  int modelYear,
) async {
  final values = <String, double>{};
  try {
    for (final command in signalSet.commandsFor(modelYear)) {
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
      for (final signal in command.signals) {
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
