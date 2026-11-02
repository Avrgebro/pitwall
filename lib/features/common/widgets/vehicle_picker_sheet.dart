import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/vehicles/vehicle.dart';
import '../../../state/focus_state.dart';
import '../../../state/infrastructure.dart';
import '../../../state/session_state.dart';
import '../../../state/settings_state.dart';
import '../../../ui/ui.dart';

/// A sheet for choosing the vehicle in focus, shared by Home and Developer
/// tools. While a car is live, the app follows it, so the others wait.
abstract final class VehiclePickerSheet {
  static Future<void> show(BuildContext context, {required String title}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Insets.l, 0, Insets.l, Insets.xl),
          child: SafeArea(top: false, child: _Choices(title: title)),
        ),
      );
}

class _Choices extends ConsumerWidget {
  const _Choices({required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(appSettingsProvider).value?.vehicles ?? [];
    final focused = ref.watch(focusedVehicleProvider);
    final liveId = ref.watch(liveVehicleIdProvider);
    final connected = ref.watch(sessionProvider).isConnected;
    final now = ref.watch(nowProvider);
    final live = vehicles.where((v) => v.id == liveId).firstOrNull;

    String state(Vehicle vehicle) => switch (vehicle.lastSeen) {
      _ when vehicle.id == live?.id => connected ? 'Connected' : 'Connecting',
      final seen? => 'Last seen ${Formatters.ago(seen, now)}',
      null => 'Never connected',
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
