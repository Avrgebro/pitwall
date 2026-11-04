import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../state/settings_state.dart';
import '../ui/theme/app_theme.dart';
import 'router.dart';
import 'settings_error_screen.dart';

class PitwallApp extends ConsumerWidget {
  const PitwallApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Settings that can't be read stop the app here, before setup could
    // save over them.
    final unreadable = ref.watch(
      appSettingsProvider.select((s) => s.hasError && !s.hasValue),
    );
    return DynamicColorBuilder(
      builder: (light, dark) => unreadable
          ? MaterialApp(
              title: 'Pitwall',
              theme: AppTheme.light(light),
              darkTheme: AppTheme.dark(dark),
              home: const SettingsErrorScreen(),
            )
          : MaterialApp.router(
              title: 'Pitwall',
              theme: AppTheme.light(light),
              darkTheme: AppTheme.dark(dark),
              routerConfig: ref.watch(routerProvider),
            ),
    );
  }
}
