import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/format/text_query.dart';
import '../theme/tokens.dart';
import 'glass_surface.dart';
import 'info_note.dart';

/// A search field that narrows a list, with a note under it when a search
/// leaves nothing. It sits on the same frosted glass as the cards around
/// it, and its outline turns to the accent colour while typing.
class FilterField extends StatelessWidget {
  const FilterField({
    super.key,
    required this.hintText,
    required this.noun,
    required this.query,
    required this.matches,
    required this.onChanged,
    this.autoFocus = false,
  });

  final String hintText;

  /// What's listed, for the note, like `devices`.
  final String noun;

  /// What's typed now, and how many items it leaves.
  final TextQuery query;
  final int matches;

  final ValueChanged<TextQuery> onChanged;
  final bool autoFocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassSurface(
          borderRadius: Corners.heroRadius,
          child: SearchBar(
            hintText: hintText,
            leading: const Icon(Symbols.search_rounded),
            autoFocus: autoFocus,
            onChanged: (text) => onChanged(TextQuery(text)),
            // The glass is the background, and its edge the outline at rest.
            elevation: const WidgetStatePropertyAll(0),
            backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            side: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.focused)
                  ? BorderSide(color: scheme.primary)
                  : BorderSide.none,
            ),
            hintStyle: WidgetStatePropertyAll(
              theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        if (!query.isEmpty && matches == 0) ...[
          const SizedBox(height: Insets.m),
          InfoNote(text: TextSpan(text: 'No $noun match "${query.text}".')),
        ],
      ],
    );
  }
}
