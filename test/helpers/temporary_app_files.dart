import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Puts the app's private storage in a temporary directory for the test,
/// removed afterwards, and returns it.
Directory useTemporaryAppFiles() {
  final directory = Directory.systemTemp.createTempSync('pitwall');
  PathProviderPlatform.instance = _TemporaryAppFiles(directory);
  addTearDown(() => directory.deleteSync(recursive: true));
  return directory;
}

class _TemporaryAppFiles extends PathProviderPlatform {
  _TemporaryAppFiles(this.directory);

  final Directory directory;

  @override
  Future<String?> getApplicationSupportPath() async => directory.path;
}
