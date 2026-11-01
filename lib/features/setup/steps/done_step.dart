import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/settings/settings.dart';
import '../../../core/vehicles/vehicle.dart';
import '../../../ui/ui.dart';

/// A summary of what was set up.
class DoneStep extends StatelessWidget {
  const DoneStep({
    super.key,
    required this.vehicle,
    required this.settings,
    required this.testPassed,
    required this.hasWebhook,
  });

  final Vehicle? vehicle;
  final AppSettings settings;
  final bool testPassed;
  final bool hasWebhook;

  /// Both are needed before Pitwall can start on its own.
  bool get _complete => vehicle != null && hasWebhook;

  @override
  Widget build(BuildContext context) {
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
          _complete ? 'You\'re all set' : 'Almost there',
          style: theme.textTheme.headlineLarge,
        ),
        const SizedBox(height: Insets.m),
        Text(
          _complete
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
                value: vehicle?.adapterName ?? 'Not chosen yet',
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
              SummaryRow(
                icon: Symbols.motion_sensor_active_rounded,
                label: 'Wakes up',
                value: switch (settings.wakeTrigger) {
                  WakeTrigger.carBluetooth =>
                    'When the car\'s Bluetooth connects',
                  WakeTrigger.drivingDetection => 'When driving is detected',
                },
                caption: 'Change in Settings',
                stacked: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
