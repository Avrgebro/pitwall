import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pitwall/features/developer/developer_screen.dart';
import 'package:pitwall/state/infrastructure.dart';
import 'package:pitwall/ui/ui.dart';

import '../../helpers/fakes.dart';

void main() {
  testWidgets('the log can be shared with another app', (tester) async {
    // A Pixel 9 Pro XL: 448 dp wide.
    tester.view
      ..physicalSize = const Size(1344, 2992)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final share = FakeShareGateway();
    final container = ProviderContainer(overrides: testOverrides(share: share));
    addTearDown(container.dispose);
    container
        .read(adapterLogProvider)
        .note('Car answered, 49 values supported');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const DeveloperScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Share log'));
    await tester.pumpAndSettle();

    expect(share.shared.single.subject, 'Pitwall adapter log');
    expect(
      share.shared.single.text,
      endsWith('Car answered, 49 values supported'),
    );
    // All three actions fit beside the title.
    expect(tester.takeException(), isNull);
  });
}
