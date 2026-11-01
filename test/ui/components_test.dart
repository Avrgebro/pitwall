import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pitwall/ui/ui.dart';

Widget _frame(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
);

void main() {
  testWidgets('status chip shows its label', (tester) async {
    await tester.pumpWidget(
      _frame(
        const StatusChip(
          label: 'Running',
          tone: StatusTone.active,
          emphasis: ChipEmphasis.filled,
          dot: true,
        ),
      ),
    );

    expect(find.text('Running'), findsOneWidget);
  });

  testWidgets('value grid gives an odd last value the full width', (
    tester,
  ) async {
    await tester.pumpWidget(
      _frame(
        const ValueGrid(
          values: [
            ValueTileData(label: 'Fuel', value: '47.5', unit: 'L'),
            ValueTileData(label: 'Battery', value: '13.6', unit: 'V'),
            ValueTileData(label: 'Odometer', value: '33,999', unit: 'km'),
          ],
        ),
      ),
    );

    final fuel = tester.getSize(find.widgetWithText(ValueTile, 'Fuel'));
    final odometer = tester.getSize(find.widgetWithText(ValueTile, 'Odometer'));
    expect(odometer.width, greaterThan(fuel.width * 1.9));
  });

  testWidgets('a missing value says the car didn\'t report it', (tester) async {
    await tester.pumpWidget(
      _frame(
        const ValueTile(
          data: ValueTileData(label: 'Coolant', value: null, unit: '°C'),
        ),
      ),
    );

    expect(find.text('—'), findsOneWidget);
    expect(find.text('Car didn\'t report this'), findsOneWidget);
  });

  testWidgets('status card shows stats and actions', (tester) async {
    await tester.pumpWidget(
      _frame(
        StatusCard(
          tone: StatusTone.error,
          icon: Icons.error,
          title: 'The webhook is refusing readings',
          message: 'Not authorised (HTTP 401)',
          stats: const [
            (label: 'Failed', value: '12'),
            (label: 'Queued', value: '12'),
          ],
          actions: [
            FilledButton(onPressed: () {}, child: const Text('Settings')),
          ],
        ),
      ),
    );

    expect(find.text('The webhook is refusing readings'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('secret field hides its value until asked', (tester) async {
    final controller = TextEditingController(text: 'https://secret');
    await tester.pumpWidget(
      _frame(SecretTextField(controller: controller, label: 'Webhook URL')),
    );

    bool obscured() =>
        tester.widget<TextField>(find.byType(TextField)).obscureText;
    expect(obscured(), isTrue);

    await tester.tap(find.byTooltip('Show'));
    await tester.pump();
    expect(obscured(), isFalse);
  });

  testWidgets('checklist row offers a fix only when needed', (tester) async {
    var fixed = false;
    await tester.pumpWidget(
      _frame(
        Column(
          children: [
            const ChecklistRow(
              title: 'Bluetooth permission',
              subtitle: 'Allowed',
              done: true,
            ),
            ChecklistRow(
              title: 'Notifications',
              subtitle: 'Off',
              done: false,
              onFix: () => fixed = true,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Fix'), findsOneWidget);
    await tester.tap(find.text('Fix'));
    expect(fixed, isTrue);
  });
}
