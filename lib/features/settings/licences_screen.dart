import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../state/licences_state.dart';
import '../../ui/ui.dart';

/// The packages Pitwall is built with, each opening its licences.
class LicencesScreen extends ConsumerWidget {
  const LicencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppPage(
    title: 'Open-source libraries',
    children: switch (ref.watch(licencesProvider)) {
      AsyncData(:final value) => [
        RowGroup(
          children: [
            for (final package in value)
              GroupTile(
                icon: Symbols.package_2_rounded,
                title: package.name,
                subtitle: _count(package.texts.length),
                onTap: () => context.push(Routes.packageLicences(package.name)),
              ),
          ],
        ),
      ],
      AsyncError() => const [
        InfoNote(
          icon: Icons.error_outline,
          text: TextSpan(text: 'Couldn\'t read the licences.'),
        ),
      ],
      _ => const [
        Padding(
          padding: EdgeInsets.all(Insets.xxl),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    },
  );

  static String _count(int count) =>
      count == 1 ? '1 licence' : '$count licences';
}

/// One package's licence texts, readable and selectable.
class PackageLicencesScreen extends ConsumerWidget {
  const PackageLicencesScreen({super.key, required this.package});

  final String package;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final licences = ref
        .watch(licencesProvider)
        .value
        ?.where((p) => p.name == package)
        .firstOrNull;
    final mono = Theme.of(context).textTheme.mono;
    return AppPage(
      title: package,
      subtitle: licences == null
          ? null
          : LicencesScreen._count(licences.texts.length),
      children: [
        for (final (index, text) in (licences?.texts ?? const []).indexed) ...[
          if (index > 0) const SizedBox(height: Insets.m),
          ContentCard(child: SelectableText(text, style: mono)),
        ],
      ],
    );
  }
}
