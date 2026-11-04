import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../state/attention_state.dart';
import '../state/permissions_state.dart';
import '../ui/ui.dart';

/// The three tabs and their navigation bar. Each tab keeps its own
/// navigation stack; sub-screens open above the bar.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  // Permissions can change in Android settings while Pitwall is away, and
  // the Settings badge depends on them.
  late final _lifecycle = AppLifecycleListener(
    onResume: () => ref.read(permissionsProvider.notifier).refresh(),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  StatefulNavigationShell get navigationShell => widget.navigationShell;

  @override
  Widget build(BuildContext context) {
    final settingsNeedAttention = ref.watch(settingsAttentionProvider);
    final vehiclesNeedAttention = ref.watch(vehiclesAttentionProvider);

    return Scaffold(
      // Content scrolls behind the floating bar.
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: FloatingNavBar(
        selectedIndex: navigationShell.currentIndex,
        onSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          FloatingNavDestination(
            icon: Symbols.directions_car_rounded,
            label: 'Vehicles',
            showBadge: vehiclesNeedAttention,
          ),
          const FloatingNavDestination(
            icon: Symbols.home_rounded,
            label: 'Home',
          ),
          FloatingNavDestination(
            icon: Symbols.settings_rounded,
            label: 'Settings',
            showBadge: settingsNeedAttention,
          ),
        ],
      ),
    );
  }
}
