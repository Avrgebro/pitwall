import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'page_backdrop.dart';
import 'pinned_bottom.dart';

/// The ground of every screen: the glowing backdrop, an optional top bar
/// that content scrolls under, and an optional [bottom] pinned over the
/// content. `AppPage` and setup's steps build on it.
class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.body,
    this.appBar,
    this.bottom,
    this.floatingActionButton,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;

  /// Pinned over the bottom of [body]; see [PinnedBottom].
  final Widget? bottom;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final bottom = this.bottom;
    return Scaffold(
      extendBodyBehindAppBar: appBar != null,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: PageBackdrop(
        child: bottom == null
            ? body
            : PinnedBottom(bottom: bottom, child: body),
      ),
    );
  }
}

/// Buttons floating at the bottom of a page, kept clear of the system
/// navigation bar. Use as a page's `bottom`.
class PinnedActions extends StatelessWidget {
  const PinnedActions({
    super.key,
    required this.child,
    this.padding = Insets.card,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(padding: padding, child: child),
  );
}
