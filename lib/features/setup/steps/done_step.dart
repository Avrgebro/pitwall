import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/vehicles/vehicle.dart';
import '../../../state/webhook_state.dart';
import '../../../ui/ui.dart';
import '../../common/trip_start_text.dart';

/// A summary of what was set up.
class DoneStep extends ConsumerWidget {
  const DoneStep({super.key, required this.vehicle});

  final Vehicle? vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final webhook = ref.watch(webhookProvider).value;
    final hasWebhook = webhook?.hasUrl ?? false;
    final testPassed = webhook?.testPassed ?? false;
    // Both are needed before Pitwall can start on its own.
    final complete = vehicle != null && hasWebhook;
    final theme = Theme.of(context);
    final healthy = context.tone(StatusTone.healthy).accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const IconBadge(
          icon: Symbols.check_rounded,
          size: Sizes.illustration,
          shape: BoxShape.circle,
        ),
        const SizedBox(height: Insets.xl),
        Text(
          complete ? 'You\'re all set' : 'Almost there',
          style: theme.textTheme.headlineLarge,
        ),
        const SizedBox(height: Insets.m),
        Text(
          complete
              ? 'Pitwall will start on its own when you drive. You can close '
                    'the app.'
              : 'Pitwall starts on its own once it has a vehicle and a '
                    'webhook. Add what\'s missing from Vehicles and Settings.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Insets.xl),
        ContentCard(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.l,
            vertical: Insets.s,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SummaryRow(
                icon: Symbols.directions_car_rounded,
                label: 'Vehicle',
                value: vehicle?.name ?? 'Not added yet',
              ),
              SummaryRow(
                icon: Symbols.bluetooth_rounded,
                label: 'Adapter',
                value: vehicle?.adapter?.name ?? 'Not chosen yet',
              ),
              SummaryRow(
                icon: Symbols.webhook_rounded,
                label: 'Webhook',
                value: switch ((hasWebhook, testPassed)) {
                  (false, _) => 'Not set yet',
                  (true, true) => 'Test passed',
                  (true, false) => 'Not tested yet',
                },
                valueColor: testPassed ? healthy : null,
              ),
              SummaryRow.stacked(
                icon: Symbols.bluetooth_drive_rounded,
                label: 'Trip start',
                value: switch (vehicle) {
                  final vehicle? => TripStartText.summary(vehicle).text,
                  null => 'Add a vehicle first',
                },
                caption: 'On the vehicle\'s page',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
