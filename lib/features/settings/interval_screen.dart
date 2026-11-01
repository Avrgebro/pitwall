import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/settings.dart';
import '../../state/settings_state.dart';
import '../../ui/ui.dart';

class IntervalScreen extends ConsumerWidget {
  const IntervalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interval = ref.watch(
      appSettingsProvider.select((settings) => settings.value?.interval),
    );
    return AppPage(
      title: 'Reading interval',
      children: [
        RadioGroup<Duration>(
          groupValue: interval,
          onChanged: (choice) {
            if (choice != null) {
              ref.read(appSettingsProvider.notifier).setInterval(choice);
            }
          },
          child: RowGroup(
            children: [
              for (final choice in AppSettings.intervalChoices)
                ChoiceRow<Duration>(
                  value: choice,
                  title: Formatters.interval(choice),
                  subtitle: choice == AppSettings.defaultInterval
                      ? 'Recommended'
                      : null,
                ),
            ],
          ),
        ),
        const InfoNote(
          text: TextSpan(
            text:
                'While driving, Pitwall reads the car and sends one reading '
                'per interval. Shorter means fresher values and more requests '
                'to the car and the webhook.',
          ),
        ),
      ],
    );
  }
}
