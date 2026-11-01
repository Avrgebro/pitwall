import 'package:flutter_test/flutter_test.dart';
import 'package:pitwall/main.dart';
import 'package:pitwall/settings/settings.dart';

import 'settings/fake_settings_store.dart';

void main() {
  testWidgets('without an adapter, points to settings', (tester) async {
    await tester.pumpWidget(PitwallApp(store: FakeSettingsStore()));
    await tester.pump();

    expect(find.text('No adapter chosen yet.'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
  });

  testWidgets('with a saved adapter, offers to connect to it', (tester) async {
    final store = FakeSettingsStore(
      settings: const Settings(
        adapterAddress: '00:11:22:33:44:55',
        adapterName: 'OBDII',
      ),
    );

    await tester.pumpWidget(PitwallApp(store: store));
    await tester.pump();

    expect(find.text('Connect to OBDII'), findsOneWidget);
  });
}
