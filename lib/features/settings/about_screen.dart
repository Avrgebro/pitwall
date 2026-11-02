import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/links.dart';
import '../../app/routes.dart';
import '../../state/infrastructure.dart';
import '../../ui/ui.dart';

/// Version, licence and credits.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(packageInfoProvider).value;
    final external = Icon(
      Symbols.open_in_new_rounded,
      color: Theme.of(context).colorScheme.primary,
    );
    return AppPage(
      title: 'About Pitwall',
      children: [
        RowGroup(
          children: [
            GroupTile(
              icon: Symbols.info_rounded,
              title: 'Version',
              subtitle: info == null
                  ? '…'
                  : '${info.version} (${info.buildNumber})',
            ),
            GroupTile(
              icon: Symbols.code_rounded,
              title: 'Source code',
              subtitle: 'github.com/Avrgebro/pitwall',
              trailing: external,
              onTap: () => launchUrl(Links.repository),
            ),
            GroupTile(
              icon: Symbols.balance_rounded,
              title: 'Open-source licence',
              subtitle: 'GPLv3',
              trailing: external,
              onTap: () => launchUrl(Links.licence),
            ),
          ],
        ),
        const SectionHeader('Credits', icon: Symbols.favorite_rounded),
        RowGroup(
          children: [
            GroupTile(
              icon: Symbols.database_rounded,
              title: 'OBDb',
              subtitle: 'Vehicle profiles, CC BY-SA 4.0. Not bundled.',
              trailing: external,
              onTap: () => launchUrl(Links.obdb),
            ),
            GroupTile(
              icon: Symbols.library_books_rounded,
              title: 'Open-source libraries',
              subtitle: 'Licences of the packages Pitwall is built with',
              onTap: () => context.push(Routes.licences),
            ),
          ],
        ),
      ],
    );
  }
}
