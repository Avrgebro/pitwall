import '../../../core/format/formatters.dart';

import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/profiles/profile_ref.dart';
import '../../../core/profiles/stored_profile.dart';
import '../../../core/vehicles/vehicle.dart';
import '../../../ui/ui.dart';

/// The vehicle's OBDb profile file and the model year it's read for.
/// Without a profile, an invitation to import one; with one that can't be
/// read, a way to replace or remove it.
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
  final StoredProfile profile;
  final VoidCallback onImport;
  final VoidCallback onRemove;
  final ValueChanged<int> onModelYear;

  /// Model years offered: OBD-II became mandatory in 1996.
  static List<int> years(DateTime now) => [
    for (var year = now.year + 1; year >= 1996; year--) year,
  ];

  @override
  Widget build(BuildContext context) {
    switch (profile) {
      case UnreadableProfile(:final ref):
        return _Unreadable(
          fileName: ref.name,
          onImport: onImport,
          onRemove: onRemove,
        );
      case NoProfile():
        return _Empty(onImport: onImport);
      case LoadedProfile(:final ref):
        return _loaded(ref);
    }
  }

  Widget _loaded(ProfileRef ref) {
    final imported = ref.importedAt;
    return ContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardHeader(
            badge: const IconBadge(icon: Symbols.data_object_rounded),
            title: 'OBDb profile',
            subtitle: [
              ref.name,
              if (imported != null) 'imported ${Formatters.date(imported)}',
            ].join(', '),
          ),
          const SizedBox(height: Insets.l),
          DropdownButtonFormField<int>(
            initialValue: vehicle.modelYear,
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
          if (vehicle.modelYear == null)
            const InfoNote(
              text: TextSpan(
                text:
                    'A profile covers several model years. Choose yours to '
                    'see what it adds.',
              ),
              padding: EdgeInsets.only(top: Insets.m),
            ),
          const SizedBox(height: Insets.l),
          ButtonGroup(
            buttons: [
              GroupButton(
                icon: Symbols.swap_horiz_rounded,
                label: 'Replace profile',
                onPressed: onImport,
              ),
              GroupButton(
                icon: Symbols.delete_rounded,
                tooltip: 'Remove profile',
                tone: StatusTone.error,
                onPressed: onRemove,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return DashedCard(
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

  final String fileName;
  final VoidCallback onImport;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => StatusCard(
    tone: StatusTone.error,
    icon: Symbols.error_rounded,
    title: 'Profile can\'t be read',
    message:
        '$fileName is missing or damaged, so only '
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
