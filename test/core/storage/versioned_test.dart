import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/storage/versioned.dart';

void main() {
  String? read(String source) => decodeVersioned(source, {
    0: (json) => 'v0 ${json['text']}',
    1: (json) => 'v1 ${json['text']}',
    2: (json) => switch (json['data']) {
      final String text => 'v2 $text',
      _ => null,
    },
  });

  test('the current version reads its data', () {
    expect(read(encodeVersioned(2, 'hello')), 'v2 hello');
  });

  test('formats from before the envelope read the whole object', () {
    expect(read('{"text": "old"}'), 'v0 old');
    expect(read('{"version": 1, "text": "older"}'), 'v1 older');
  });

  test('what it can\'t read is nothing, whatever the reason', () {
    for (final source in [
      'not json',
      '[1, 2]',
      '{"version": "2", "data": "x"}',
      // A newer version's data.
      '{"version": 3, "data": "x"}',
      // A reader that finds nothing it can use.
      '{"version": 2, "data": 7}',
    ]) {
      expect(read(source), isNull, reason: source);
    }
  });

  test('an envelope\'s data is found only if it\'s an object', () {
    expect(
      dataOf({
        'data': {'a': 1},
      }),
      {'a': 1},
    );
    expect(dataOf({'data': 'text'}), isNull);
  });
}
