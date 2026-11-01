import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../ui/ui.dart';
import '../home_view_model.dart';

/// The vehicle's status at the top of Home: state chip, name, what Pitwall
/// is doing, and adapter / car / trip.
class VehicleHeroCard extends StatelessWidget {
  const VehicleHeroCard({super.key, required this.model});

  final HeroModel model;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final running = model.state == HeroState.running;
    // Running tints the glass in the accent; otherwise it's neutral glass.
    final tint = running
        ? context.tone(StatusTone.active).container.withValues(alpha: 0.7)
        : null;
    final foreground = running
        ? context.tone(StatusTone.active).onContainer
        : scheme.onSurface;
    final tileBackground = scheme.surface.withValues(alpha: 0.4);

    return GlassSurface(
      borderRadius: Corners.heroRadius,
      color: tint,
      child: Padding(
        padding: const EdgeInsets.all(Insets.l + 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _chip(),
            const SizedBox(height: Insets.l),
            Text(
              model.title,
              style: theme.textTheme.displaySmall?.copyWith(color: foreground),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              model.subtitle,
              style: theme.textTheme.bodyLarge?.copyWith(color: foreground),
            ),
            const SizedBox(height: Insets.l),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < model.stats.length; i++) ...[
                    if (i > 0) const SizedBox(width: Insets.s),
                    Expanded(
                      child: StatTile(
                        icon: _icon(model.stats[i].kind),
                        label: model.stats[i].label,
                        value: model.stats[i].value,
                        background: tileBackground,
                        foreground: foreground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip() => switch (model.state) {
    HeroState.running => const StatusChip(
      label: 'Running',
      tone: StatusTone.active,
      emphasis: ChipEmphasis.filled,
      dot: true,
    ),
    HeroState.connecting => const StatusChip(
      label: 'Connecting',
      tone: StatusTone.active,
      icon: Symbols.bluetooth_searching_rounded,
    ),
    HeroState.waiting => const StatusChip(
      label: 'Waiting for the car',
      emphasis: ChipEmphasis.outlined,
      icon: Symbols.radio_button_unchecked_rounded,
    ),
  };

  static IconData _icon(HeroStatKind kind) => switch (kind) {
    HeroStatKind.adapter => Symbols.bluetooth_rounded,
    HeroStatKind.adapterMissing => Symbols.bluetooth_disabled_rounded,
    HeroStatKind.car => Symbols.directions_car_rounded,
    HeroStatKind.carOff => Symbols.power_settings_new_rounded,
    HeroStatKind.trip => Symbols.timer_rounded,
    HeroStatKind.lastTrip => Symbols.history_rounded,
  };
}
