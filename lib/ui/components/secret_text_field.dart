import 'package:material_ui/material_ui.dart';

import '../theme/status_colors.dart';
import '../theme/tokens.dart';
import 'info_note.dart';

/// A text field for secrets (webhook URL, tokens): hidden by default with a
/// show/hide toggle, a reassurance line, and room for a warning.
class SecretTextField extends StatefulWidget {
  const SecretTextField({
    super.key,
    required this.controller,
    required this.label,
    this.helperText,
    this.warning,
    this.errorText,
    this.validator,
    this.onChanged,
    this.keyboardType,
    this.multilineWhenShown = false,
  });

  final TextEditingController controller;
  final String label;

  /// Shown with a lock icon, e.g. "Stored securely on this phone".
  final String? helperText;

  /// A caution that doesn't block, like an unencrypted URL. Shown in place
  /// of the helper text.
  final InlineSpan? warning;
  final String? errorText;

  /// Checks the text once the user has edited it, showing what it returns
  /// as the error. For checks that need no outside state.
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;

  /// Wraps long values onto several lines while visible.
  final bool multilineWhenShown;

  @override
  State<SecretTextField> createState() => _SecretTextFieldState();
}

class _SecretTextFieldState extends State<SecretTextField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final warning = context.tone(StatusTone.warning);
    final hasWarning = widget.warning != null && widget.errorText == null;
    final warningBorder = OutlineInputBorder(
      borderRadius: Corners.smallRadius,
      borderSide: BorderSide(color: warning.accent, width: 1.5),
    );
    final multiline = widget.multilineWhenShown && _visible;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          validator: widget.validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          obscureText: !_visible,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: multiline
              ? TextInputType.multiline
              : widget.keyboardType,
          maxLines: multiline ? null : 1,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            labelText: widget.label,
            errorText: widget.errorText,
            labelStyle: hasWarning ? TextStyle(color: warning.accent) : null,
            floatingLabelStyle: hasWarning
                ? TextStyle(color: warning.accent)
                : null,
            enabledBorder: hasWarning ? warningBorder : null,
            focusedBorder: hasWarning ? warningBorder : null,
            suffixIcon: IconButton(
              icon: Icon(_visible ? Icons.visibility_off : Icons.visibility),
              tooltip: _visible ? 'Hide' : 'Show',
              onPressed: () => setState(() => _visible = !_visible),
            ),
          ),
        ),
        if (hasWarning)
          InfoNote(
            icon: Icons.warning_amber_rounded,
            textColor: warning.accent,
            text: widget.warning!,
            dense: true,
            // Lined up with the field's edge, a little apart from it.
            padding: const EdgeInsets.only(top: Insets.s),
          )
        else if (widget.helperText != null && widget.errorText == null)
          InfoNote(
            icon: Icons.lock_outline,
            text: TextSpan(text: widget.helperText),
            dense: true,
            padding: const EdgeInsets.only(top: Insets.s),
          ),
      ],
    );
  }
}
