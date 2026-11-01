import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/profiles/signal_set.dart';
import '../../../core/vehicles/vehicle.dart';
import '../../../ui/ui.dart';
import '../../common/profile_text.dart';

/// The vehicle's OBDb profile: what it adds, which model year applies, and
/// what was skipped. Without a profile, an invitation to import one.
class ProfileCard extends StatelessWidget {
  const ProfileCard({
    super.key,
    required this.vehicle,
    required this.profile,
    required this.onImport,
    required this.onRemove,
    required this.onModelYear,
  });

  final Vehicle vehicle;
  final SignalSet? profile;
  final VoidCallback onImport;
  final VoidCallback onRemove;
  final ValueChanged<int> onModelYear;

  /// Model years offered: OBD-II became mandatory in 1996.
  static List<int> years(DateTime now) => [
    for (var year = now.year + 1; year >= 1996; year--) year,
  ];

  @override
  Widget build(BuildContext context) {
    final profile = this.profile;
    if (profile == null) return _Empty(onImport: onImport);

    final theme = Theme.of(context);
    final year = vehicle.modelYear;
    final skipped = ProfileText.skippedSummary(profile.skipped);
    final imported = vehicle.profileImportedAt;
    final healthy = context.tone(StatusTone.healthy);

    return GroupCard(
      dividers: true,
      children: [
        Padding(
          padding: Insets.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const IconBadge(icon: Symbols.data_object_rounded),
                  const SizedBox(width: Insets.l),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OBDb profile',
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          [
                            vehicle.profileName ?? 'profile.json',
                            if (imported != null)
                              'imported ${Formatters.date(imported)}',
                          ].join(' · '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.l),
              DropdownButtonFormField<int>(
                initialValue: year,
                decoration: const InputDecoration(labelText: 'Model year'),
                hint: const Text('Choose the model year'),
                items: [
                  for (final option in years(DateTime.now()))
                    DropdownMenuItem(value: option, child: Text('$option')),
                ],
                onChanged: (value) {
                  if (value != null) onModelYear(value);
                },
              ),
              const SizedBox(height: Insets.m),
              Row(
                children: [
                  Icon(
                    year == null ? Icons.info_outline : Icons.check_circle,
                    size: Sizes.iconSmall,
                    color: year == null
                        ? theme.colorScheme.onSurfaceVariant
                        : healthy.accent,
                  ),
                  const SizedBox(width: Insets.s),
                  Text(
                    year == null
                        ? 'Choose the year to use this profile'
                        : ProfileText.applies(profile, year),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (skipped.isNotEmpty)
          ExpansionTile(
            title: Text('Skipped: ${profile.skipped.length}'),
            childrenPadding: const EdgeInsets.fromLTRB(
              Insets.l,
              0,
              Insets.l,
              Insets.m,
            ),
            children: [
              for (final item in skipped)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Insets.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: Insets.xl,
                        child: Text(
                          '${item.count}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item.reason,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.all(Insets.m),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: onImport,
                icon: const Icon(Symbols.swap_horiz_rounded),
                label: const Text('Replace'),
              ),
              const SizedBox(width: Insets.s),
              TextButton(onPressed: onRemove, child: const Text('Remove')),
            ],
          ),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GroupCard(
      dashed: true,
      padding: Insets.card,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const IconBadge(
              icon: Symbols.data_object_rounded,
              tone: StatusTone.neutral,
            ),
            const SizedBox(width: Insets.l),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Standard values only',
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    'Import a profile for extras like fuel in litres and the '
                    'real odometer.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.l),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: onImport,
            icon: const Icon(Symbols.upload_file_rounded),
            label: const Text('Import profile'),
          ),
        ),
      ],
    );
  }
}
