import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'state/infrastructure.dart';
import 'state/settings_state.dart';
import 'state/trip_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // What fails is shown, and tried again when the user asks or what it
  // depends on changes; never retried on its own, which could ask for a
  // permission unbidden, or start Bluetooth scans past Android's limit.
  final container = ProviderContainer(retry: (_, _) => null);
  // Settings decide the first screen. If they can't be read, the app
  // starts anyway and says so; see PitwallApp.
  try {
    await container.read(appSettingsProvider.future);
  } on Object {
    // Reported where they're read, and shown by the app.
  }
  // Queued readings resume right away. Never throws; see init.
  await container.read(webhookSenderProvider).init();
  // Listens for Android's trip requests, also when started without a
  // screen by the trip service.
  container.read(tripProvider);
  runApp(
    UncontrolledProviderScope(container: container, child: const PitwallApp()),
  );
}
