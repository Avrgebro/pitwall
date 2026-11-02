import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/profiles/signal_set.dart';
import '../../../core/vehicles/vehicle.dart';
import '../../../ui/ui.dart';
import '../../common/profile_text.dart';

/// The vehicle's OBDb profile: what it adds, which model year applies, and
/// what was skipped. Without a profile, an invitation to import one; with
/// one that can't be read, a way to replace or remove it.
class ProfileCard extends StatelessWidget {
  const ProfileCard({
    super.key,
    required this.vehicle,
    required this.profile,
    this.unreadable = false,
    required this.onImport,
    required this.onRemove,
    required this.onModelYear,
  });

  final Vehicle vehicle;
  final SignalSet? profile;

  /// The vehicle has a profile, but its file can't be read.
  final bool unreadable;
  final VoidCallback onImport;
  final VoidCallback onRemove;
  final ValueChanged<int> onModelYear;

  /// Model years offered: OBD-II became mandatory in 1996.
  static List<int> years(DateTime now) => [
    for (var year = now.year + 1; year >= 1996; year--) year,
  ];

  @override
  Widget build(BuildContext context) {
    if (unreadable) {
      return _Unreadable(
        fileName: vehicle.profileName,
        onImport: onImport,
        onRemove: onRemove,
      );
    }
    final profile = this.profile;
    if (profile == null) return _Empty(onImport: onImport);

    final theme = Theme.of(context);
    final year = vehicle.modelYear;
    final skipped = ProfileText.skippedSummary(profile.skipped);
    final imported = vehicle.profileImportedAt;
    final healthy = context.tone(StatusTone.healthy);

    return RowGroup(
      children: [
        Padding(
          padding: Insets.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CardHeader(
                badge: const IconBadge(icon: Symbols.data_object_rounded),
                title: 'OBDb profile',
                subtitle: [
                  vehicle.profileName ?? 'profile.json',
                  if (imported != null) 'imported ${Formatters.date(imported)}',
                ].join(', '),
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
              InfoNote(
                icon: year == null ? Icons.info_outline : Icons.check_circle,
                iconColor: year == null
                    ? theme.colorScheme.onSurfaceVariant
                    : healthy.accent,
                textColor: theme.colorScheme.onSurface,
                text: TextSpan(
                  text: year == null
                      ? 'Choose the year to use this profile'
                      : ProfileText.applies(profile, year),
                ),
                padding: const EdgeInsets.only(top: Insets.m),
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
    return ContentCard(
      dashed: true,
      padding: Insets.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CardHeader(
            badge: IconBadge(
              icon: Symbols.data_object_rounded,
              tone: StatusTone.neutral,
            ),
            title: 'Standard values only',
            subtitle:
                'Import a profile to add your car\'s own signals to the '
                'values you can send.',
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
      ),
    );
  }
}

class _Unreadable extends StatelessWidget {
  const _Unreadable({
    required this.fileName,
    required this.onImport,
    required this.onRemove,
  });

  final String? fileName;
  final VoidCallback onImport;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => StatusCard(
    tone: StatusTone.error,
    icon: Symbols.error_rounded,
    title: 'Profile can\'t be read',
    message:
        '${fileName ?? 'The profile file'} is missing or damaged, so only '
        'standard values are sent. Import it again, or remove it.',
    actions: [
      FilledButton.icon(
        onPressed: onImport,
        icon: const Icon(Symbols.upload_file_rounded),
        label: const Text('Import again'),
      ),
      TextButton(onPressed: onRemove, child: const Text('Remove')),
    ],
  );
}
