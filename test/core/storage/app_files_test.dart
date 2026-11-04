import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pitwall/core/readings/last_values.dart';

/// The app's private storage, in a temporary directory.
class _TemporaryAppFiles extends PathProviderPlatform {
  _TemporaryAppFiles(this.directory);

  final Directory directory;

  @override
  Future<String?> getApplicationSupportPath() async => directory.path;
}

void main() {
  late Directory directory;
  setUp(() {
    directory = Directory.systemTemp.createTempSync('pitwall');
    PathProviderPlatform.instance = _TemporaryAppFiles(directory);
  });
  tearDown(() => directory.deleteSync(recursive: true));

  File file(String name) => File('${directory.path}/$name');

  test('a file from a newer version is set aside, not written over', () async {
    const newer = '{"version": 99, "data": {"tucson": {}}}';
    file('last_values.json').writeAsStringSync(newer);
    final storage = FileLastValuesStorage();

    expect((await storage.load()).byVehicle, isEmpty);
    await storage.save(
      const LastValues().record(
        'tucson',
        {'rpm': 800},
        DateTime(2026, 11, 3),
        seq: 1,
      ),
    );

    expect(file('last_values.json.unreadable').readAsStringSync(), newer);
    expect((await storage.load()).byVehicle['tucson']?['rpm']?.value, 800);
  });

  test('a file saved before versions is read as it is', () async {
    file('last_values.json').writeAsStringSync(
      '{"tucson": {"rpm": {"value": 800, "at": "2026-11-03T10:00:00.000", "seq": 1}}}',
    );

    final values = await FileLastValuesStorage().load();

    expect(values.byVehicle['tucson']?['rpm']?.seq, 1);
    expect(file('last_values.json.unreadable').existsSync(), isFalse);
  });
}
