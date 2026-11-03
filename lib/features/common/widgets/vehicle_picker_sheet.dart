import '../../../core/format/formatters.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/vehicles/vehicle.dart';
import '../../../state/focus_state.dart';
import '../../../state/infrastructure.dart';
import '../../../state/live_activity_state.dart';
import '../../../state/settings_state.dart';
import '../../../ui/ui.dart';

/// A sheet for choosing the vehicle in focus, shared by Home and Developer
/// tools. While a car is live, the app follows it, so the others wait.
abstract final class VehiclePickerSheet {
  static Future<void> show(BuildContext context, {required String title}) =>
      showAppSheet<void>(context, builder: (context) => _Choices(title: title));
}

class _Choices extends ConsumerWidget {
  const _Choices({required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(appSettingsProvider).value?.vehicles ?? [];
    final focused = ref.watch(focusedVehicleProvider);
    final activity = ref.watch(liveActivityProvider);
    final now = ref.watch(nowProvider);
    final live = switch (activity) {
      VehicleActivity(:final vehicleId) =>
        vehicles.where((v) => v.id == vehicleId).firstOrNull,
      LiveSearching() || NoActivity() => null,
    };

    String state(Vehicle vehicle) => switch (activity.forVehicle(vehicle.id)) {
      LiveConnected() => 'Connected',
      LiveConnecting() => 'Connecting',
      LiveReconnecting() => 'Reconnecting',
      LiveSearching() => 'Looking for its adapter',
      NoActivity() => switch (vehicle.lastSeen) {
        final seen? => 'Last seen ${Formatters.ago(seen, now)}',
        null => 'Never connected',
      },
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title, padding: SectionHeader.firstPadding),
        RadioGroup<String>(
          groupValue: focused?.id,
          onChanged: (id) {
            if (id == null) return;
            ref.read(focusPickProvider.notifier).pick(id);
            Navigator.pop(context);
          },
          child: RowGroup(
            children: [
              for (final vehicle in vehicles)
                ChoiceRow<String>(
                  value: vehicle.id,
                  title: vehicle.name,
                  subtitle: state(vehicle),
                  enabled: live == null || vehicle.id == live.id,
                ),
            ],
          ),
        ),
        InfoNote(
          text: TextSpan(
            text: live == null
                ? 'When a car connects, Pitwall switches to it.'
                : 'While ${live.name} is connected, Pitwall stays on it.',
          ),
        ),
      ],
    );
  }
}
