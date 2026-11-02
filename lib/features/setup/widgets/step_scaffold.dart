import 'package:material_ui/material_ui.dart';

import '../../../ui/ui.dart';

/// The frame of a setup step: progress, a headline, content, and the
/// buttons to move on. Setup hides the navigation bar.
class StepScaffold extends StatelessWidget {
  const StepScaffold({
    super.key,
    required this.step,
    required this.steps,
    required this.children,
    required this.primaryLabel,
    required this.onPrimary,
    this.title,
    this.message,
    this.onBack,
    this.footnote,
    this.onSkip,
  });

  /// 1-based.
  final int step;
  final int steps;
  final String? title;
  final String? message;
  final List<Widget> children;
  final String primaryLabel;

  /// Null disables the button.
  final VoidCallback? onPrimary;

  /// Null hides the Back button; the primary button then spans the width.
  final VoidCallback? onBack;
  final String? footnote;

  /// Offers "Set up later" for a step that can be done afterwards.
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PageFrame(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(Insets.xl, Insets.l, Insets.xl, 0),
        child: _Progress(step: step, steps: steps),
      ),
      padding: const EdgeInsets.all(Insets.xl),
      bottom: PinnedActions(
        // Lined up with the step's content.
        padding: const EdgeInsets.fromLTRB(
          Insets.xl,
          Insets.s,
          Insets.xl,
          Insets.l,
        ),
        child: _buttons(),
      ),
      children: [
        if (title != null) Text(title!, style: theme.textTheme.headlineMedium),
        if (message != null) ...[
          const SizedBox(height: Insets.s),
          Text(
            message!,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (title != null || message != null) const SizedBox(height: Insets.xl),
        ...children,
        if (footnote != null) ...[
          const SizedBox(height: Insets.xl),
          Text(
            footnote!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  /// Glass, as they float over the step's content.
  Widget _buttons() {
    final primary = GlassButton(
      onPressed: onPrimary,
      child: Text(primaryLabel),
    );
    if (onBack == null) return SizedBox(width: double.infinity, child: primary);
    return Row(
      children: [
        GlassButton.neutral(onPressed: onBack, child: const Text('Back')),
        const Spacer(),
        // Always in view, however long the step is.
        if (onSkip != null) ...[
          GlassButton.neutral(
            onPressed: onSkip,
            child: const Text('Set up later'),
          ),
          const SizedBox(width: Insets.s),
        ],
        primary,
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step, required this.steps});

  final int step;
  final int steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 1; i <= steps; i++) ...[
              if (i > 1) const SizedBox(width: Insets.xsPlus),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= step
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: Insets.m),
        Text(
          'Step $step of $steps',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
