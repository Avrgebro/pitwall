import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/core/format/text_query.dart';

void main() {
  test('matches any field, ignoring case and surrounding spaces', () {
    final query = TextQuery('  OBD ');
    expect(query.text, 'OBD');
    expect(query.matches(['Car stereo', 'vLinker obd']), isTrue);
    expect(query.matches(['Car stereo', 'AA:BB']), isFalse);
  });

  test('an empty query matches everything', () {
    expect(TextQuery('   ').isEmpty, isTrue);
    expect(TextQuery.none.matches(['anything']), isTrue);
  });
}
