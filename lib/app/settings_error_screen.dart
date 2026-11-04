import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../state/settings_state.dart';
import '../ui/ui.dart';

/// Shown instead of the app when its settings can't be read. Nothing is
/// set up again over them: setup would save over settings that may only
/// be out of reach for now.
class SettingsErrorScreen extends ConsumerWidget {
  const SettingsErrorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppPage(
    title: 'Pitwall',
    children: [
      const InfoNote(
        tone: StatusTone.error,
        text: TextSpan(
          text:
              'Pitwall couldn\'t read its settings on this phone. Nothing '
              'was changed or deleted. Try again, or restart the phone if it '
              'keeps happening.',
        ),
      ),
      const SizedBox(height: Insets.m),
      FilledButton(
        onPressed: () => ref.invalidate(appSettingsProvider),
        child: const Text('Try again'),
      ),
    ],
  );
}
