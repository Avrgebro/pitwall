import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/storage/versioned.dart';

void main() {
  Saved<String> read(String? source) => readVersioned(
    source,
    readers: {
      2: (data) => switch (data) {
        final String text => 'v2 $text',
        _ => null,
      },
    },
    before: {
      0: (json) => 'v0 ${json['text']}',
      1: (json) => 'v1 ${json['text']}',
    },
  );

  String? value(Saved<String> saved) => switch (saved) {
    SavedData(:final value) => value,
    _ => null,
  };

  test('the current version reads its data', () {
    expect(value(read(encodeVersioned(2, 'hello'))), 'v2 hello');
  });

  test('formats from before the envelope read the whole object', () {
    expect(value(read('{"text": "old"}')), 'v0 old');
    expect(value(read('{"version": 1, "text": "older"}')), 'v1 older');
  });

  test('nothing saved is not the same as unreadable', () {
    expect(read(null), isA<NothingSaved<String>>());
  });

  test('what it can\'t read is unreadable, whatever the reason', () {
    for (final source in [
      'not json',
      '[1, 2]',
      '{"version": "2", "data": "x"}',
      // A newer version's data.
      '{"version": 3, "data": "x"}',
      // A reader that finds nothing it can use.
      '{"version": 2, "data": 7}',
    ]) {
      expect(read(source), isA<UnreadableData<String>>(), reason: source);
    }
  });
}
