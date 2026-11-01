import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/theme/app_theme.dart';
import 'router.dart';

class PitwallApp extends ConsumerWidget {
  const PitwallApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => DynamicColorBuilder(
    builder: (light, dark) => MaterialApp.router(
      title: 'Pitwall',
      theme: AppTheme.light(light),
      darkTheme: AppTheme.dark(dark),
      routerConfig: ref.watch(routerProvider),
    ),
  );
}
