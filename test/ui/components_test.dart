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

  testWidgets('a section header centres its icon on the title', (tester) async {
    await tester.pumpWidget(
      _frame(
        const SectionHeader(
          'Delivery',
          icon: Icons.cloud_upload,
          trailing: '2 rows',
        ),
      ),
    );

    final icon = tester.getCenter(find.byIcon(Icons.cloud_upload)).dy;
    final title = tester.getCenter(find.text('Delivery')).dy;
    expect(icon, moreOrLessEquals(title, epsilon: 0.5));
  });

  testWidgets('a note keeps its icon on the first line of long text', (
    tester,
  ) async {
    await tester.pumpWidget(
      _frame(
        SizedBox(
          width: 200,
          child: InfoNote(text: TextSpan(text: 'A long note that wraps ' * 4)),
        ),
      ),
    );

    final icon = tester.getRect(find.byIcon(Icons.info_outline));
    final text = tester.getRect(find.byType(RichText).last);
    expect(text.height, greaterThan(icon.height * 2));
    expect(icon.top, greaterThanOrEqualTo(text.top));
    expect(icon.bottom, lessThan(text.top + text.height / 2));
  });

  testWidgets('the selected option outlines its segment in the accent', (
    tester,
  ) async {
    final theme = AppTheme.light();
    await tester.pumpWidget(
      _frame(
        RadioGroup<int>(
          groupValue: 2,
          onChanged: (_) {},
          child: const RowGroup(
            children: [
              ChoiceRow(value: 1, title: 'One'),
              ChoiceRow(value: 2, title: 'Two'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Color outlineOf(String title) {
      final box = tester.widget<AnimatedContainer>(
        find.ancestor(
          of: find.text(title),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final shape =
          (box.foregroundDecoration! as ShapeDecoration).shape
              as RoundedRectangleBorder;
      return shape.side.color;
    }

    expect(outlineOf('Two'), theme.colorScheme.primary);
    expect(outlineOf('One').a, 0);
  });

  testWidgets('glass buttons are standard height, floating height pinned', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: PinnedBottom(
          bottom: GlassButton(onPressed: () {}, child: const Text('Pinned')),
          child: Center(
            child: GlassButton(onPressed: () {}, child: const Text('Inline')),
          ),
        ),
      ),
    );

    double heightOf(String label) => tester
        .getSize(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(FilledButton),
          ),
        )
        .height;
    expect(heightOf('Pinned'), Sizes.floatingControl);
    expect(heightOf('Inline'), 48);
  });

  testWidgets('a step number is centred on its title', (tester) async {
    await tester.pumpWidget(
      _frame(const NumberedSteps(steps: [NumberedStep('Add it here')])),
    );

    final number = tester.getCenter(find.text('1')).dy;
    final title = tester.getCenter(find.text('Add it here')).dy;
    expect(number, moreOrLessEquals(title, epsilon: 0.5));
  });
}
