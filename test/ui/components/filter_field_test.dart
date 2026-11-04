import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pitwall/core/format/text_query.dart';
import 'package:pitwall/ui/ui.dart';

void main() {
  Widget field(TextQuery query, {bool shown = true}) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: shown
          ? FilterField(
              hintText: 'Search devices',
              noun: 'devices',
              query: query,
              matches: 1,
              onChanged: (_) {},
            )
          : const SizedBox(),
    ),
  );

  String shownText(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText)).controller.text;

  testWidgets('built again, it shows what still filters', (tester) async {
    // As when the list goes to an error and comes back.
    await tester.pumpWidget(field(TextQuery('vlink')));
    await tester.pumpWidget(field(TextQuery('vlink'), shown: false));
    await tester.pumpWidget(field(TextQuery('vlink')));

    expect(shownText(tester), 'vlink');
  });

  testWidgets('a query cleared from outside clears the text', (tester) async {
    await tester.pumpWidget(field(TextQuery.none));
    await tester.enterText(find.byType(TextField), 'obd ');
    await tester.pumpWidget(field(TextQuery('obd')));
    // Typing isn't undone: trimmed, it is the query.
    expect(shownText(tester), 'obd ');

    await tester.pumpWidget(field(TextQuery.none));
    expect(shownText(tester), isEmpty);
  });
}
