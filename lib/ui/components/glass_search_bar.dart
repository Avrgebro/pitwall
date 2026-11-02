import 'package:material_ui/material_ui.dart';

import 'glass_surface.dart';

/// A search field on the same frosted glass as the cards around it. The
/// outline turns to the accent colour while typing.
class GlassSearchBar extends StatelessWidget {
  const GlassSearchBar({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.leading,
    this.autoFocus = false,
  });

  final String hintText;
  final ValueChanged<String> onChanged;
  final Widget? leading;
  final bool autoFocus;

  static const _radius = BorderRadius.all(Radius.circular(28));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassSurface(
      borderRadius: _radius,
      child: SearchBar(
        hintText: hintText,
        leading: leading,
        autoFocus: autoFocus,
        onChanged: onChanged,
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
          Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
