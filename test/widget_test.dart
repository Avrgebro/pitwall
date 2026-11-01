import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pitwall/main.dart';
import 'package:pitwall/settings/settings.dart';
import 'package:pitwall/vehicles/vehicle.dart';
import 'package:pitwall/webhook/webhook_sender.dart';

import 'settings/fake_settings_store.dart';
import 'webhook/fake_delivery_storage.dart';

void main() {
  late WebhookSender sender;

  setUp(() {
    sender = WebhookSender(
      storage: FakeDeliveryStorage(),
      webhookTarget: () async => null,
      client: MockClient((_) async => http.Response('', 200)),
    );
  });

  tearDown(() => sender.dispose());

  testWidgets('without a vehicle, points to settings', (tester) async {
    await tester.pumpWidget(
      PitwallApp(store: FakeSettingsStore(), sender: sender),
    );
    await tester.pump();

    expect(find.text('No adapter chosen yet.'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
  });

  testWidgets('with a vehicle, offers to connect to its adapter', (
    tester,
  ) async {
    final store = FakeSettingsStore(
      settings: const AppSettings(
        vehicles: [
          Vehicle(
            id: 'tucson',
            adapterAddress: '00:11:22:33:44:55',
            adapterName: 'OBDII',
          ),
        ],
      ),
    );

    await tester.pumpWidget(PitwallApp(store: store, sender: sender));
    await tester.pump();

    expect(find.text('Connect to OBDII'), findsOneWidget);
  });
}
