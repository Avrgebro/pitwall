import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pitwall/core/webhook/webhook_auth.dart';
import 'package:pitwall/features/common/widgets/auth_editor.dart';
import 'package:pitwall/ui/ui.dart';

/// Hosts the editor the way the webhook page does: it reports changes and
/// gets the new credentials and their problem back.
class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  WebhookAuth auth = WebhookAuth.none;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: AuthEditor(
          auth: auth,
          onChanged: (value) => setState(() => auth = value),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('every type is listed, with no fields while None is chosen', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host());

    for (final title in [
      'None',
      'Bearer token',
      'Username and password',
      'Custom header',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('choosing a type opens its fields inside its option', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host());

    await tester.tap(find.text('Username and password'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Username'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);

    await tester.tap(find.text('Bearer token'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Username'), findsNothing);
    expect(find.widgetWithText(TextField, 'Token'), findsOneWidget);
  });

  testWidgets('a problem shows on its field only after it is edited', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host());
    await tester.tap(find.text('Bearer token'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the token.'), findsNothing);

    final token = find.widgetWithText(TextField, 'Token');
    await tester.enterText(token, 'abc');
    await tester.enterText(token, '');
    await tester.pump();
    expect(find.text('Enter the token.'), findsOneWidget);
  });

  testWidgets('switching types keeps what was typed', (tester) async {
    await tester.pumpWidget(const _Host());
    await tester.tap(find.text('Bearer token'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Token'), 'abc');
    await tester.pump();

    await tester.tap(find.text('None'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bearer token'));
    await tester.pumpAndSettle();

    final state = tester.state<_HostState>(find.byType(_Host));
    expect(state.auth.token, 'abc');
    expect(find.text('abc'), findsOneWidget);
  });
}
