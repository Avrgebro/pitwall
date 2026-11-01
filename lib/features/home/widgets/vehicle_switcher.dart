import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/vehicles/vehicle.dart';
import '../../../state/home_state.dart';
import '../../../state/infrastructure.dart';
import '../../../state/session_state.dart';
import '../../../state/settings_state.dart';
import '../../../ui/ui.dart';

/// A sheet for choosing which vehicle Home shows. While a car is connected,
/// Home shows that one, so the others wait until it disconnects.
abstract final class VehicleSwitcher {
  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => const SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(Insets.l, 0, Insets.l, Insets.xl),
      child: SafeArea(top: false, child: _Choices()),
    ),
  );
}

class _Choices extends ConsumerWidget {
  const _Choices();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(appSettingsProvider).value?.vehicles ?? [];
    final shown = ref.watch(homeVehicleProvider);
    final session = ref.watch(sessionProvider);
    final now = ref.watch(nowProvider);
    final live = vehicles.where((v) => v.id == session.vehicleId).firstOrNull;

    String state(Vehicle vehicle) => switch (vehicle.lastSeen) {
      _ when vehicle.id == live?.id =>
        session.isConnected ? 'Connected' : 'Connecting',
      final seen? => 'Last seen ${Formatters.ago(seen, now)}',
      null => 'Never connected',
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          'Show on Home',
          padding: EdgeInsets.fromLTRB(Insets.xs, 0, Insets.xs, Insets.s),
        ),
        RadioGroup<String>(
          groupValue: shown?.id,
          onChanged: (id) {
            if (id == null) return;
            ref.read(homePickProvider.notifier).pick(id);
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
                ? 'Home goes back to following your cars when one connects.'
                : 'While ${live.name} is connected, Home shows it.',
          ),
        ),
      ],
    );
  }
}
