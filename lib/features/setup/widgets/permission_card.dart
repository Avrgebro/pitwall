import 'package:material_ui/material_ui.dart';

import '../../../ui/ui.dart';

/// One permission in setup: what it's for, and either "Allowed" or a
/// button to allow it.
class PermissionCard extends StatelessWidget {
  const PermissionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.purpose,
    required this.granted,
    required this.onAllow,
  });

  final IconData icon;
  final String title;
  final String purpose;
  final bool granted;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final healthy = context.tone(StatusTone.healthy);
    return GroupCard(
      padding: Insets.card,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(
              icon: icon,
              tone: granted ? StatusTone.active : StatusTone.neutral,
              shape: BoxShape.circle,
            ),
            const SizedBox(width: Insets.l),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    purpose,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Insets.s),
            if (granted)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: Sizes.iconSmall,
                    color: healthy.accent,
                  ),
                  const SizedBox(width: Insets.xs),
                  Text(
                    'Allowed',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: healthy.accent,
                    ),
                  ),
                ],
              )
            else
              FilledButton(
                onPressed: onAllow,
                style: FilledButton.styleFrom(minimumSize: const Size(64, 36)),
                child: const Text('Allow'),
              ),
          ],
        ),
      ],
    );
  }
}
