import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/platform/file_gateway.dart';
import '../../core/profiles/stored_profile.dart';
import '../../core/readings/readings.dart';
import '../../core/vehicles/vehicle.dart';
import '../../state/infrastructure.dart';
import '../../state/settings_state.dart';
import '../../ui/ui.dart';
import '../common/profile_text.dart';
import 'widgets/profile_card.dart';
import 'widgets/profile_contents.dart';
import 'widgets/vehicle_page.dart';

/// The vehicle's optional OBDb profile: import, model year, what applies.
class VehicleProfileScreen extends ConsumerWidget {
  const VehicleProfileScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => VehiclePage(
    vehicleId: vehicleId,
    title: 'Vehicle profile',
    builder: (context, vehicle, values) => _page(context, ref, vehicle, values),
  );

  Widget _page(
    BuildContext context,
    WidgetRef ref,
    Vehicle vehicle,
    VehicleValues values,
  ) {
    // Loading a profile maps every failure to UnreadableProfile, so an
    // error here can only come from the settings; it reads the same way.
    final stored = switch (ref.watch(vehicleProfileProvider(vehicleId))) {
      // Kept while it reloads, as after an import.
      AsyncValue(:final value?) => value,
      AsyncError() => switch (vehicle.profile) {
        final ref? => UnreadableProfile(ref),
        null => const NoProfile(),
      },
      AsyncLoading() => null,
    };
    final notifier = ref.read(appSettingsProvider.notifier);
    return AppPage(
      title: 'Vehicle profile',
      children: [
        if (stored == null)
          const LoadingIndicator()
        else
          ProfileCard(
            vehicle: vehicle,
            profile: stored,
            onImport: () => _import(context, ref, vehicle),
            onRemove: () => _remove(context, ref, vehicle, stored),
            onModelYear: (year) => notifier.setModelYear(vehicle.id, year),
          ),
        if ((stored, values.profile) case (LoadedProfile(), final summary?))
          ProfileContents(
            summary: summary,
            selected: values.sent,
            onOpenValues: (category) => context.push(
              Routes.vehicleValues(vehicle.id, category: category),
            ),
          ),
        const InfoNote(
          icon: Icons.help_outline,
          text: TextSpan(
            text:
                'Optional. Profiles come from OBDb, a community catalogue of '
                'what each car can report beyond the standard values. '
                'Download your car\'s signalsets/v3/default.json from '
                'github.com/OBDb and import it here. Pitwall asks the car in '
                'requests, and one request can return several values.',
          ),
        ),
      ],
    );
  }

  /// Removes the profile at once, with Undo while the message shows. A
  /// profile that couldn't be read has nothing to put back.
  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    Vehicle vehicle,
    StoredProfile stored,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(appSettingsProvider.notifier);
    await notifier.removeProfile(vehicle.id);
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Profile removed'),
        action: switch (stored) {
          final LoadedProfile profile => SnackBarAction(
            label: 'Undo',
            onPressed: () => notifier.restoreProfile(
              vehicle.id,
              profile,
              modelYear: vehicle.modelYear,
            ),
          ),
          NoProfile() || UnreadableProfile() => null,
        },
      ),
    );
  }

  Future<void> _import(
    BuildContext context,
    WidgetRef ref,
    Vehicle vehicle,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    String message;
    try {
      final file = await ref.read(fileGatewayProvider).pickJson();
      if (file == null) return;
      final profile = await ref
          .read(appSettingsProvider.notifier)
          .importProfile(vehicle.id, file);
      final year = vehicle.modelYear;
      message = year == null
          ? 'Profile imported. Choose the model year.'
          : 'Profile imported: '
                '${ProfileText.forYear(profile.summaryFor(year))}';
    } on UnreadableFileException catch (e) {
      message = e.tooLarge
          ? 'That file is too large to be a profile.'
          : 'That file isn\'t text.';
    } on FormatException catch (e) {
      message = 'That isn\'t an OBDb profile: ${e.message}';
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}
