import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../ui/ui.dart';

/// What Pitwall does, in three lines.
class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key});

  static const _points = [
    (
      icon: Symbols.bluetooth_rounded,
      text:
          'Reads fuel, odometer, battery and more from a cheap Bluetooth '
          'OBD-II adapter',
    ),
    (
      icon: Symbols.webhook_rounded,
      text: 'Sends them as JSON to your webhook, usually Home Assistant',
    ),
    (
      icon: Symbols.motion_sensor_active_rounded,
      text: 'Starts by itself when you drive. No need to open it in the car.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const IconBadge(
          icon: Symbols.sensors_rounded,
          size: Sizes.illustration,
        ),
        const SizedBox(height: Insets.xl),
        Text(
          'Your car\'s data, in Home Assistant',
          style: theme.textTheme.headlineLarge,
        ),
        const SizedBox(height: Insets.m),
        Text(
          'Pitwall is a quiet companion. Set it up once and forget about it.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Insets.xl),
        for (final point in _points)
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.l),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconBadge(
                  icon: point.icon,
                  tone: StatusTone.neutral,
                  shape: BoxShape.circle,
                ),
                const SizedBox(width: Insets.l),
                Expanded(
                  child: Text(point.text, style: theme.textTheme.bodyLarge),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
