import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'line_icon.dart';

@immutable
class NumberedStep {
  const NumberedStep(this.title, {this.detail});

  final String title;

  /// A quieter line under the title.
  final String? detail;
}

/// Steps to follow, each with its number in a small circle.
class NumberedSteps extends StatelessWidget {
  const NumberedSteps({super.key, required this.steps});

  final List<NumberedStep> steps;

  static const _number = 28.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titleStyle = theme.textTheme.bodyLarge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0) const SizedBox(height: Insets.m),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FirstLineCentered(
                style: titleStyle,
                child: Container(
                  width: _number,
                  height: _number,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Insets.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(steps[i].title, style: titleStyle),
                    if (steps[i].detail case final detail?)
                      Text(
                        detail,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
