import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/developer/developer_screen.dart';
import '../features/home/home_screen.dart';
import '../features/settings/credits_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/setup/setup_screen.dart';
import '../features/vehicles/add_vehicle_screen.dart';
import '../features/vehicles/values_to_send_screen.dart';
import '../features/vehicles/vehicle_detail_screen.dart';
import '../features/vehicles/vehicles_screen.dart';
import '../state/settings_state.dart';
import 'app_shell.dart';
import 'routes.dart';

final _rootNavigator = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Three tabs in a shell; sub-screens and setup open on the root navigator,
/// above the navigation bar. Until setup is done, every path leads there.
final routerProvider = Provider<GoRouter>((ref) {
  final setupDone = ValueNotifier(
    ref.read(appSettingsProvider).value?.setupDone ?? false,
  );
  ref.listen(
    appSettingsProvider.select((settings) => settings.value?.setupDone),
    (_, done) => setupDone.value = done ?? false,
  );

  GoRoute subScreen(String path, Widget Function(GoRouterState) build) =>
      GoRoute(
        path: path,
        parentNavigatorKey: _rootNavigator,
        builder: (_, state) => build(state),
      );

  final router = GoRouter(
    navigatorKey: _rootNavigator,
    initialLocation: Routes.home,
    refreshListenable: setupDone,
    redirect: (_, state) {
      final inSetup = state.matchedLocation == Routes.setup;
      if (!setupDone.value && !inSetup) return Routes.setup;
      if (setupDone.value && inSetup) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(path: Routes.setup, builder: (_, _) => const SetupScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.vehicles,
                builder: (_, _) => const VehiclesScreen(),
                routes: [
                  // Before ':id', so "add" isn't taken for an id.
                  subScreen('add', (_) => const AddVehicleScreen()),
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: _rootNavigator,
                    builder: (_, state) => VehicleDetailScreen(
                      vehicleId: state.pathParameters['id']!,
                    ),
                    routes: [
                      subScreen(
                        'values',
                        (state) => ValuesToSendScreen(
                          vehicleId: state.pathParameters['id']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (_, _) => const SettingsScreen(),
                routes: [
                  subScreen('credits', (_) => const CreditsScreen()),
                  subScreen('developer', (_) => const DeveloperScreen()),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    setupDone.dispose();
  });
  return router;
});
