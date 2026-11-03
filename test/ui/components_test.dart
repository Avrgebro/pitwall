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
          emphasis: Emphasis.filled,
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
            (icon: Icons.sync_problem, label: 'Failed', value: '12'),
            (icon: Icons.pending, label: 'Queued', value: '12'),
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
        const SectionHeader.icon(
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
        home: PageFrame(
          bottom: GlassButton(onPressed: () {}, child: const Text('Pinned')),
          slivers: [
            SliverToBoxAdapter(
              child: Center(
                child: GlassButton(
                  onPressed: () {},
                  child: const Text('Inline'),
                ),
              ),
            ),
          ],
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

  group('sliver row group', () {
    Widget sliverFrame(int count, IndexedWidgetBuilder builder) => _frame(
      CustomScrollView(
        slivers: [SliverRowGroup(itemCount: count, itemBuilder: builder)],
      ),
    );

    testWidgets('builds only the rows on screen', (tester) async {
      final built = <int>{};
      await tester.pumpWidget(
        sliverFrame(300, (context, index) {
          built.add(index);
          return SizedBox(height: 56, child: Text('Row $index'));
        }),
      );

      expect(built, contains(0));
      expect(built.length, lessThan(30));
    });

    testWidgets('keeps the group\'s outer and inner corners', (tester) async {
      await tester.pumpWidget(
        sliverFrame(3, (context, index) => Text('Row $index')),
      );
      BorderRadius corners(int index) =>
          RowSegment.borderRadiusOf(tester.element(find.text('Row $index')));
      const outer = Radius.circular(Corners.extraLarge);

      expect(corners(0).topLeft, outer);
      expect(corners(1).topLeft, isNot(outer));
      expect(corners(1).bottomLeft, isNot(outer));
      expect(corners(2).bottomLeft, outer);
    });
  });

  testWidgets('anything on tinted glass takes the tint\'s text colours', (
    tester,
  ) async {
    await tester.pumpWidget(
      _frame(
        const GlassSurface(
          tone: StatusTone.error,
          child: InfoNote(text: TextSpan(text: 'Check the token')),
        ),
      ),
    );

    final context = tester.element(find.byType(InfoNote));
    final onContainer = context.tone(StatusTone.error).onContainer;
    final text = tester.widget<Text>(find.text('Check the token'));
    expect(text.style?.color, onContainer.withValues(alpha: 0.75));
  });

  testWidgets('a toned note takes the tone\'s accent', (tester) async {
    await tester.pumpWidget(
      _frame(
        const InfoNote(
          tone: StatusTone.error,
          text: TextSpan(text: 'Couldn\'t read the licences.'),
        ),
      ),
    );

    final context = tester.element(find.byType(InfoNote));
    final text = tester.widget<Text>(find.text('Couldn\'t read the licences.'));
    expect(text.style?.color, context.tone(StatusTone.error).accent);
  });

  testWidgets('a failed save of typed text is reported', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SaveWhenDone(
            onDone: () async => throw StateError('disk full'),
            child: const TextField(),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(tester.takeException(), isA<StateError>());

    // Leaving the screen saves too, and that failure is reported as well.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isA<StateError>());
  });

  testWidgets('plain text and icons on tinted glass take the tint', (
    tester,
  ) async {
    final theme = AppTheme.light();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: GlassSurface(
            tone: StatusTone.error,
            child: Column(
              children: [
                Text('Plain'),
                Icon(Icons.error_outline),
                _BodyMedium(),
              ],
            ),
          ),
        ),
      ),
    );

    final tint = theme.extension<StatusColors>()!.error.onContainer;
    Color? colorOf(String text) => tester
        .widget<RichText>(
          find.descendant(of: find.text(text), matching: find.byType(RichText)),
        )
        .text
        .style
        ?.color;
    expect(colorOf('Plain'), tint);
    expect(colorOf('Body'), tint);
    expect(
      IconTheme.of(tester.element(find.byIcon(Icons.error_outline))).color,
      tint,
    );
  });
}

/// Text in the theme's body style, with no colour of its own.
class _BodyMedium extends StatelessWidget {
  const _BodyMedium();

  @override
  Widget build(BuildContext context) =>
      Text('Body', style: Theme.of(context).textTheme.bodyMedium);
}
