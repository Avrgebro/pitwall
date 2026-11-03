import 'package:material_ui/material_ui.dart';

import '../../../core/vehicles/device_id.dart';
import '../../../ui/ui.dart';

/// The vehicle's name, with the `device` id it becomes in every reading
/// shown live underneath.
class VehicleNameField extends StatefulWidget {
  const VehicleNameField({
    super.key,
    required this.initialName,
    this.onChanged,
    this.onDone,
    this.note,
    this.autofocus = false,
  });

  final String initialName;
  final ValueChanged<String>? onChanged;

  /// Called with the name when typing is done; see [SaveWhenDone].
  final Future<void> Function(String name)? onDone;

  /// An extra sentence after the id, like "You can change it later."
  final String? note;
  final bool autofocus;

  @override
  State<VehicleNameField> createState() => _VehicleNameFieldState();
}

class _VehicleNameFieldState extends State<VehicleNameField> {
  late final _controller = TextEditingController(text: widget.initialName);

  /// What's typed, kept apart from the controller: the last save can come
  /// after the controller is disposed.
  late String _typed = widget.initialName;

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
    final mono = theme.textTheme.mono.copyWith(fontWeight: FontWeight.w600);
    final name = _controller.text.trim();
    final field = TextField(
      controller: _controller,
      autofocus: widget.autofocus,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(labelText: 'Vehicle name'),
      onChanged: (text) {
        setState(() => _typed = text);
        widget.onChanged?.call(text);
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        switch (widget.onDone) {
          final onDone? => SaveWhenDone(
            onDone: () => onDone(_typed),
            child: field,
          ),
          null => field,
        },
        Padding(
          // Lined up with the field's edge, like the other field notes.
          padding: const EdgeInsets.only(top: Insets.s),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'Sent as ', style: muted),
                TextSpan(text: 'device', style: mono),
                if (name.isNotEmpty) ...[
                  TextSpan(text: ': ', style: muted),
                  TextSpan(text: deviceIdFor(name), style: mono),
                ],
                TextSpan(text: ' in every reading.', style: muted),
                if (widget.note != null)
                  TextSpan(text: ' ${widget.note}', style: muted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
