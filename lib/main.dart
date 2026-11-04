import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'state/infrastructure.dart';
import 'state/settings_state.dart';
import 'state/trip_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  // Settings decide the first screen; queued readings resume right away.
  await container.read(appSettingsProvider.future);
  await container.read(webhookSenderProvider).init();
  // Listens for Android's trip requests, also when started without a
  // screen by the trip service.
  container.read(tripProvider);
  runApp(
    UncontrolledProviderScope(container: container, child: const PitwallApp()),
  );
}
