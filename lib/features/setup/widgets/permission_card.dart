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
    final healthy = context.tone(StatusTone.healthy).accent;
    return ContentCard(
      child: CardHeader(
        badge: IconBadge(
          icon: icon,
          tone: granted ? StatusTone.active : StatusTone.neutral,
          shape: BoxShape.circle,
        ),
        title: title,
        subtitle: purpose,
        trailing: granted
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: Sizes.iconSmall,
                    color: healthy,
                  ),
                  const SizedBox(width: Insets.xs),
                  Text(
                    'Allowed',
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: healthy),
                  ),
                ],
              )
            : FilledButton(
                onPressed: onAllow,
                style: FilledButton.styleFrom(minimumSize: const Size(64, 36)),
                child: const Text('Allow'),
              ),
      ),
    );
  }
}
