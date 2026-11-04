import 'dart:convert';

/// Saved data in the one shape every store writes: the data, with the
/// version of its format. See [decodeVersioned].
String encodeVersioned(int version, Object? data) =>
    jsonEncode({'version': version, 'data': data});

/// How a store reads each version of its format, given the whole saved
/// object. A version saved by [encodeVersioned] finds its data under
/// `data` ([dataOf]); formats from before kept their fields next to
/// `version`, and a file with no version at all is version 0.
///
/// Readers are lenient, leaving out what doesn't fit, and return null only
/// when nothing does.
typedef VersionReaders<T> = Map<int, T? Function(Map<String, Object?> json)>;

/// The data [encodeVersioned] saved in [json], if it's an object.
Map<String, Object?>? dataOf(Map<String, Object?> json) =>
    switch (json['data']) {
      final Map<String, Object?> data => data,
      _ => null,
    };

/// What [source] holds, read by the reader for its version, or null if it
/// can't be read: it doesn't parse, or its version has no reader, as when
/// a newer version of the app saved it.
///
/// The policy for every store: what was read but can't be understood is
/// set aside, never written over, and the store starts as if nothing were
/// saved. The copy set aside is only kept, never read back, so a downgrade
/// can't destroy a newer version's data, nor bring old data back over what
/// was set up since.
T? decodeVersioned<T>(String source, VersionReaders<T> readers) {
  final Object? json;
  try {
    json = jsonDecode(source);
  } on FormatException {
    return null;
  }
  if (json is! Map<String, Object?>) return null;
  return switch (json['version'] ?? 0) {
    final int version => readers[version]?.call(json),
    _ => null,
  };
}
