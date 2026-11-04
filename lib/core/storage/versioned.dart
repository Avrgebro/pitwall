import 'dart:convert';

/// Saved data in the one shape every store writes: the data, with the
/// version of its format. See [readVersioned].
String encodeVersioned(int version, Object? data) =>
    jsonEncode({'version': version, 'data': data});

/// What a store found where it saves.
sealed class Saved<T> {
  const Saved();
}

/// Data the store could read, brought up to date.
final class SavedData<T> extends Saved<T> {
  const SavedData(this.value);

  final T value;
}

/// Nothing saved yet.
final class NothingSaved<T> extends Saved<T> {
  const NothingSaved();
}

/// Saved data the store can't read: it doesn't parse, or its version has no
/// reader, as when a newer version of the app saved it.
///
/// The policy for every store: what it can't read is set aside, never
/// written over, and the store starts as if nothing were saved. The copy
/// set aside is only kept, never read back, so a downgrade can't destroy a
/// newer version's data, nor bring old data back over what was set up since.
final class UnreadableData<T> extends Saved<T> {
  const UnreadableData();
}

/// Reads [source], saved by [encodeVersioned] or by a format from before it.
///
/// [readers] read the data of each version saved by [encodeVersioned].
/// [before] read the formats from before it, which kept their fields next
/// to `version`, given the whole object; a file with no version at all is
/// version 0. Readers are lenient, leaving out what doesn't fit, and
/// return null only when nothing does: the data is then unreadable.
Saved<T> readVersioned<T>(
  String? source, {
  required Map<int, T? Function(Object? data)> readers,
  Map<int, T? Function(Map<String, Object?> json)> before = const {},
}) {
  if (source == null) return const NothingSaved();
  final Object? json;
  try {
    json = jsonDecode(source);
  } on FormatException {
    return const UnreadableData();
  }
  if (json is! Map<String, Object?>) return const UnreadableData();
  final version = json['version'] ?? 0;
  if (version is! int) return const UnreadableData();
  final value = switch ((readers[version], before[version])) {
    (final read?, _) => read(json['data']),
    (null, final read?) => read(json),
    (null, null) => null,
  };
  return value == null ? const UnreadableData() : SavedData(value);
}
