import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'state/infrastructure.dart';
import 'state/settings_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  // Settings decide the first screen; queued readings resume right away.
  await container.read(appSettingsProvider.future);
  await container.read(webhookSenderProvider).init();
  runApp(
    UncontrolledProviderScope(container: container, child: const PitwallApp()),
  );
}
