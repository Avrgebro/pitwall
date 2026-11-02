import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// A file in the app's private storage.
Future<File> appFile(String name) async =>
    File('${(await getApplicationSupportDirectory()).path}/$name');

/// Writes [contents] through a temporary file, so a crash mid-write can't
/// leave a half-written file behind.
Future<void> writeAtomically(File file, String contents) async {
  final temporary = File('${file.path}.tmp');
  await temporary.writeAsString(contents, flush: true);
  await temporary.rename(file.path);
}
