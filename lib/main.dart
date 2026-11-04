import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'state/infrastructure.dart';
import 'state/settings_state.dart';
import 'state/trip_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  // Settings decide the first screen. If they can't be read, the app
  // starts anyway and says so; see PitwallApp.
  try {
    await container.read(appSettingsProvider.future);
  } on Object catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'settings',
        context: ErrorDescription('while reading the settings at startup'),
      ),
    );
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
