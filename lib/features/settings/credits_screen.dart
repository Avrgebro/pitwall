import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/links.dart';
import '../../state/infrastructure.dart';
import '../../ui/ui.dart';

class CreditsScreen extends ConsumerWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(packageInfoProvider).value;
    return AppPage(
      title: 'Credits',
      children: [
        const SectionHeader('Vehicle profiles'),
        GroupCard(
          children: [
            GroupTile(
              icon: Symbols.database_rounded,
              title: 'OBDb',
              subtitle:
                  'Community documentation of vehicle signals. Pitwall reads '
                  'its signal-set files, which you download yourself; none '
                  'are bundled. OBDb data is licensed CC BY-SA 4.0.',
              trailing: const Icon(Symbols.open_in_new_rounded),
              onTap: () => launchUrl(Links.obdb),
            ),
          ],
        ),
        const SectionHeader('Pitwall'),
        GroupCard(
          children: [
            GroupTile(
              icon: Symbols.code_rounded,
              title: 'Source code',
              subtitle: 'MIT licence',
              trailing: const Icon(Symbols.open_in_new_rounded),
              onTap: () => launchUrl(Links.repository),
            ),
            GroupTile(
              icon: Symbols.library_books_rounded,
              title: 'Open-source libraries',
              subtitle: 'Licences of the packages Pitwall is built with',
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'Pitwall',
                applicationVersion: info?.version,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
