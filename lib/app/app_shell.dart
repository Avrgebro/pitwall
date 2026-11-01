import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../state/permissions_state.dart';
import '../state/webhook_state.dart';

/// The three tabs and their navigation bar. Each tab keeps its own
/// navigation stack; sub-screens open above the bar.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveryError = ref.watch(
      deliveryStatusProvider.select((status) => status.lastError),
    );
    final settingsNeedAttention =
        (deliveryError != null && !deliveryError.isTransient) ||
        ref.watch(missingPermissionsProvider) > 0;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          const NavigationDestination(
            icon: Icon(Symbols.home_rounded),
            selectedIcon: Icon(Symbols.home_rounded, fill: 1),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Symbols.directions_car_rounded),
            selectedIcon: Icon(Symbols.directions_car_rounded, fill: 1),
            label: 'Vehicles',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: settingsNeedAttention,
              child: const Icon(Symbols.settings_rounded),
            ),
            selectedIcon: Badge(
              isLabelVisible: settingsNeedAttention,
              child: const Icon(Symbols.settings_rounded, fill: 1),
            ),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
