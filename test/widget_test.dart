import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/main.dart';

void main() {
  testWidgets('starts on the device picker', (tester) async {
    await tester.pumpWidget(const PitwallApp());

    expect(find.text('Show paired devices'), findsOneWidget);
  });
}
