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
  });

  final Vehicle? vehicle;
  final AppSettings settings;
  final bool testPassed;

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
        Text('You\'re all set', style: theme.textTheme.headlineLarge),
        const SizedBox(height: Insets.m),
        Text(
          'Pitwall will start on its own when you drive. You can close the '
          'app.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Insets.xl),
        GroupCard(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.l,
            vertical: Insets.s,
          ),
          children: [
            SummaryRow(
              icon: Symbols.directions_car_rounded,
              label: 'Vehicle',
              value: vehicle?.name ?? '—',
            ),
            SummaryRow(
              icon: Symbols.bluetooth_rounded,
              label: 'Adapter',
              value: vehicle?.adapterName ?? '—',
            ),
            SummaryRow(
              icon: Symbols.webhook_rounded,
              label: 'Webhook',
              value: testPassed ? 'Test passed' : 'Not tested yet',
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
      ],
    );
  }
}
