import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pitwall/ui/ui.dart';

void main() {
  Future<void> pump(WidgetTester tester, Disclosure disclosure) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: DisclosureGroup(
              disclosure: disclosure,
              contents: '1 device',
              onToggle: () {},
            ),
          ),
        ),
      );

  testWidgets('it says what opening or closing it does', (tester) async {
    await pump(tester, const Disclosure(forced: false, open: false));
    expect(find.text('Show 1 device'), findsOneWidget);

    await pump(tester, const Disclosure(forced: false, open: true));
    expect(find.text('Hide 1 device'), findsOneWidget);
  });

  testWidgets('a list kept open has nothing to fold it', (tester) async {
    await pump(tester, const Disclosure(forced: true, open: false));

    expect(find.byType(GroupTile), findsNothing);
  });
}
