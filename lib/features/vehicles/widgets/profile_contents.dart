import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/profiles/signal_set.dart';
import '../../../ui/ui.dart';
import '../../common/profile_text.dart';

/// What a profile adds to a vehicle of one model year: the values it can
/// read, by category, and the ones it can't, by reason.
class ProfileContents extends StatelessWidget {
  const ProfileContents({
    super.key,
    required this.summary,
    required this.selected,
    required this.onOpenValues,
  });

  final ProfileSummary summary;

  /// The keys the vehicle sends.
  final Set<String> selected;

  /// Opens the values to send, only one category's with [category].
  final void Function(String? category) onOpenValues;

  @override
  Widget build(BuildContext context) {
    final readable = summary.readable;
    int on(Iterable<ProfileSignal> signals) =>
        signals.where((s) => selected.contains(s.key)).length;
    final notYet = summary.notYetReadable;
    final neverSent = summary.neverSentRequests;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('What it adds', trailing: '${summary.year}'),
        RowGroup(
          children: [
            GroupTile(
              icon: Symbols.list_alt_rounded,
              title:
                  '${ProfileText.values(readable.length)} your car can '
                  'report',
              subtitle: switch (on(readable)) {
                0 => 'None turned on yet',
                final count => '$count turned on',
              },
              onTap: () => onOpenValues(null),
            ),
            for (final SignalGroup(:category, :signals)
                in summary.readableByCategory)
              GroupTile(
                icon: _icon(category),
                title: category,
                subtitle: switch (on(signals)) {
                  0 => ProfileText.values(signals.length),
                  final turnedOn =>
                    '${ProfileText.values(signals.length)}, $turnedOn on',
                },
                onTap: () => onOpenValues(category),
              ),
          ],
        ),
        if (notYet.isNotEmpty) ...[
          const SectionHeader('Not readable yet'),
          RowGroup(
            children: [
              for (final (:reason, :signals) in notYet)
                _UnreadableRow(reason: reason, signals: signals),
            ],
          ),
        ],
        if (neverSent > 0) ...[
          const SectionHeader('Never sent'),
          RowGroup(
            children: [
              AppRow(
                leading: const Icon(Symbols.lock_rounded),
                title: ProfileText.neverSent(neverSent),
                subtitle: Text(
                  ProfileText.unreadableDetail(SkipReason.notReadOnly),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// OBDb's top-level categories; anything else gets a generic icon.
  static IconData _icon(String category) => switch (category) {
    'Engine' => Symbols.car_repair_rounded,
    'Battery' => Symbols.battery_full_rounded,
    'Movement' => Symbols.speed_rounded,
    'Trips' => Symbols.route_rounded,
    'Fuel' => Symbols.local_gas_station_rounded,
    'Tires' => Symbols.tire_repair_rounded,
    'Transmission' => Symbols.auto_transmission_rounded,
    'Doors' => Symbols.door_front_rounded,
    'Lights' => Symbols.lightbulb_rounded,
    'Seatbelts' => Symbols.airline_seat_recline_normal_rounded,
    'Climate' => Symbols.mode_fan_rounded,
    'Control' => Symbols.tune_rounded,
    _ => Symbols.category_rounded,
  };
}

/// Values a profile has but Pitwall can't read yet, for one reason; opens
/// to say why and which values.
class _UnreadableRow extends StatefulWidget {
  const _UnreadableRow({required this.reason, required this.signals});

  final SkipReason reason;
  final List<ProfileSignal> signals;

  @override
  State<_UnreadableRow> createState() => _UnreadableRowState();
}

class _UnreadableRowState extends State<_UnreadableRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final signals = widget.signals;
    final names = {for (final signal in signals) signal.name}.toList()..sort();
    return InkWell(
      onTap: () => setState(() => _open = !_open),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppRow(
            leading: const Icon(Symbols.hourglass_empty_rounded),
            title: ProfileText.unreadable(widget.reason),
            subtitle: Text(
              '${ProfileText.values(signals.length)}: '
              '${ProfileText.categories(ProfileSummary.byCategory(signals))}',
            ),
            trailing: Icon(
              _open ? Icons.expand_less : Icons.expand_more,
              color: theme.colorScheme.primary,
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(
                    padding: Insets.card.copyWith(top: 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ProfileText.unreadableDetail(widget.reason),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: Insets.s),
                        for (final name in names)
                          Padding(
                            padding: const EdgeInsets.only(top: Insets.xs),
                            child: Text(
                              name,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
