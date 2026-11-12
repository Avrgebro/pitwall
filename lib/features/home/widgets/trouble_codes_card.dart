import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../../ui/ui.dart';
import '../home_view_model.dart';

/// The check-engine light and the car's trouble codes, each as a tag under
/// its kind. Bare codes: what they mean is for the owner to look up.
class TroubleCodesCard extends StatelessWidget {
  const TroubleCodesCard({super.key, required this.model});

  final TroubleCodesModel model;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = switch ((model.checkEngine, model.groups.isEmpty)) {
      (true, _) => StatusTone.error,
      (false, true) => StatusTone.healthy,
      (false, false) => StatusTone.warning,
    };
    return ContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                model.checkEngine
                    ? Symbols.warning_rounded
                    : Symbols.check_circle_rounded,
                color: context.tone(tone).accent,
              ),
              const SizedBox(width: Insets.s),
              Expanded(
                child: Text(model.title, style: theme.textTheme.titleMedium),
              ),
            ],
          ),
          for (final group in model.groups) ...[
            const SizedBox(height: Insets.m),
            Text(
              switch (group.kind) {
                TroubleCodeKind.stored => 'Stored',
                TroubleCodeKind.pending => 'Pending',
                TroubleCodeKind.permanent => 'Permanent',
              },
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Insets.xs),
            Wrap(
              spacing: Insets.xs,
              runSpacing: Insets.xs,
              children: [
                for (final code in group.codes)
                  Tag(
                    code,
                    tone: switch (group.kind) {
                      TroubleCodeKind.stored => StatusTone.error,
                      TroubleCodeKind.pending => StatusTone.warning,
                      TroubleCodeKind.permanent => StatusTone.neutral,
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
