import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/tokens.dart';
import 'glass_search_bar.dart';
import 'info_note.dart';

/// A search field that narrows a list, with a note under it when nothing
/// is left.
class FilterField extends StatelessWidget {
  const FilterField({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.noMatchText,
    this.autoFocus = false,
  });

  final String hintText;
  final ValueChanged<String> onChanged;

  /// Shown when nothing matches, e.g. `No devices match "obd".`
  final String? noMatchText;
  final bool autoFocus;

  @override
  Widget build(BuildContext context) {
    final noMatch = noMatchText;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassSearchBar(
          hintText: hintText,
          leading: const Icon(Symbols.search_rounded),
          autoFocus: autoFocus,
          onChanged: onChanged,
        ),
        if (noMatch != null) ...[
          const SizedBox(height: Insets.m),
          InfoNote(text: TextSpan(text: noMatch)),
        ],
      ],
    );
  }
}
