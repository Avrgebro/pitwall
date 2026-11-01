import 'package:material_ui/material_ui.dart';

import '../../../ui/ui.dart';

/// The vehicle's name, which is sent as `device` in every reading.
class VehicleNameField extends StatefulWidget {
  const VehicleNameField({
    super.key,
    required this.initialName,
    required this.onChanged,
    this.helper = 'Sent as device in every reading',
    this.autofocus = false,
  });

  final String initialName;
  final ValueChanged<String> onChanged;
  final String helper;
  final bool autofocus;

  @override
  State<VehicleNameField> createState() => _VehicleNameFieldState();
}

class _VehicleNameFieldState extends State<VehicleNameField> {
  late final _controller = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final parts = widget.helper.split('device');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          autofocus: widget.autofocus,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Vehicle name'),
          onChanged: widget.onChanged,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Insets.l, Insets.xs, Insets.l, 0),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: parts.first),
                if (parts.length > 1) ...[
                  TextSpan(
                    text: 'device',
                    style: theme.textTheme.mono.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(text: parts.sublist(1).join('device')),
                ],
              ],
            ),
            style: muted,
          ),
        ),
      ],
    );
  }
}
