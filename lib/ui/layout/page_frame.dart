import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'page_backdrop.dart';
import 'pinned_bottom.dart';

/// The ground of every screen: the glowing backdrop, an optional top bar
/// that content scrolls under, an optional [header] that stays put above
/// the content, the scrolling content, and an optional [bottom] pinned
/// over it. `AppPage` and setup's steps build on it.
class PageFrame extends StatelessWidget {
  /// A frame whose content is a list of [children].
  PageFrame({
    super.key,
    required List<Widget> children,
    this.appBar,
    this.header,
    this.bottom,
    this.padding = defaultPadding,
  }) : slivers = [SliverList.list(children: children)];

  /// A frame whose content is slivers, for long lists that should only
  /// build what's on screen.
  const PageFrame.slivers({
    super.key,
    required this.slivers,
    this.appBar,
    this.header,
    this.bottom,
    this.padding = defaultPadding,
  });

  final List<Widget> slivers;
  final PreferredSizeWidget? appBar;

  /// Above the content, below the status bar, and not scrolled.
  final Widget? header;

  /// Pinned over the bottom of the content; see [PinnedBottom].
  final Widget? bottom;

  /// Around the content, inside what overlaps it.
  final EdgeInsets padding;

  static const defaultPadding = EdgeInsets.fromLTRB(
    Insets.l,
    Insets.s,
    Insets.l,
    Insets.l,
  );

  @override
  Widget build(BuildContext context) {
    final bottom = this.bottom;
    final content = Builder(builder: _content);
    return Scaffold(
      extendBodyBehindAppBar: appBar != null,
      appBar: appBar,
      body: PageBackdrop(
        child: bottom == null
            ? content
            : PinnedBottom(bottom: bottom, child: content),
      ),
    );
  }

  /// Inside the body, the scaffolds report what overlaps it: the top bar
  /// or status bar above, and below either the floating navigation bar on
  /// tab pages or the pinned [bottom]. The content keeps clear of both,
  /// and scrolls under them.
  Widget _content(BuildContext context) {
    final overlap = MediaQuery.paddingOf(context);
    final header = this.header;
    final scrollView = CustomScrollView(
      slivers: [
        SliverPadding(
          padding: padding.copyWith(
            top: (header == null ? overlap.top : 0) + padding.top,
            bottom: overlap.bottom + padding.bottom,
          ),
          sliver: SliverMainAxisGroup(slivers: slivers),
        ),
      ],
    );
    if (header == null) return scrollView;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(top: overlap.top),
          child: header,
        ),
        Expanded(child: scrollView),
      ],
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
