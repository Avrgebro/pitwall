import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// Content with [bottom] pinned over its lower edge: the content scrolls
/// behind it, and it stays just above the keyboard while typing.
///
/// Built on a scaffold's bottom slot, which reports the bottom's height in
/// the content's bottom padding (`MediaQuery.paddingOf`), for scrolling
/// content to keep clear of it. Placed inside a page's body, which the
/// page's scaffold already keeps above the keyboard.
///
/// [bottom] floats, so give it its own surface, such as a `GlassButton` or
/// a `GlassBar`, and keep it clear of the system navigation bar. Filled
/// buttons in it get the floating control height, matching the navigation
/// bar.
class PinnedBottom extends StatelessWidget {
  const PinnedBottom({super.key, required this.bottom, required this.child});

  final Widget bottom;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    extendBody: true,
    bottomNavigationBar: FilledButtonTheme(
      data: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, Sizes.floatingControl),
        ).merge(FilledButtonTheme.of(context).style),
      ),
      child: bottom,
    ),
    body: child,
  );
}
