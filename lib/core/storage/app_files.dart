import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'versioned.dart';

export 'versioned.dart';

/// A file in the app's private storage.
Future<File> appFile(String name) async =>
    File('${(await getApplicationSupportDirectory()).path}/$name');

/// What the app file [name] holds, read by [decodeVersioned], or null if
/// there's none, or it was read but can't be understood: then it's set
/// aside first, as [decodeVersioned] says.
///
/// Throws [FileSystemException] if the file is there but couldn't be read,
/// or couldn't be set aside: neither says anything about what it holds, so
/// it's left as it is. Whoever loads it then mustn't save over it.
Future<T?> readVersionedFile<T>(String name, VersionReaders<T> readers) async {
  final file = await appFile(name);
  final String source;
  try {
    source = await file.readAsString();
  } on PathNotFoundException {
    return null;
  }
  final value = decodeVersioned(source, readers);
  if (value == null) await _setAside(file);
  return value;
}

/// Writes [data] to the app file [name], as [encodeVersioned] does.
Future<void> writeVersionedFile(String name, int version, Object? data) async {
  final file = await appFile(name);
  await file.parent.create(recursive: true);
  await writeAtomically(file, encodeVersioned(version, data));
}

/// Keeps [file] beside itself, replacing any copy set aside before.
Future<void> _setAside(File file) => file.rename('${file.path}.unreadable');

/// Writes [contents] through a temporary file, so a crash mid-write can't
/// leave a half-written file behind.
Future<void> writeAtomically(File file, String contents) async {
  final temporary = File('${file.path}.tmp');
  await temporary.writeAsString(contents, flush: true);
  await temporary.rename(file.path);
}
