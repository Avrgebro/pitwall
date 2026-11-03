import 'package:material_ui/material_ui.dart';

import '../theme/glass_colors.dart';
import '../theme/glass_filters.dart';
import '../theme/tokens.dart';
import '../components/loading_indicator.dart';
import 'page_frame.dart';

/// The frame of every screen: a title (with a back button on sub-screens),
/// an optional subtitle, and scrolling content with page padding.
///
/// Content is a list of [children], or, for pages with long lists that
/// should only build what's on screen, [slivers] (see [AppPage.slivers]).
///
/// Content scrolls under the top bar. The bar is transparent at the top of
/// the page and fills in, frosted and with rounded bottom corners, once
/// content passes beneath it.
class AppPage extends StatelessWidget {
  AppPage({
    super.key,
    required this.title,
    required List<Widget> children,
    this.subtitle,
    this.actions,
    this.bottom,
  }) : slivers = [SliverList.list(children: children)];

  /// A page still loading what it shows: its title, and a spinner.
  const AppPage.loading({super.key, required this.title})
    : slivers = const [SliverToBoxAdapter(child: LoadingIndicator())],
      subtitle = null,
      actions = null,
      bottom = null;

  /// A page whose content is slivers, such as a `SliverRowGroup`, mixed
  /// with `SliverList.list` for ordinary content.
  const AppPage.slivers({
    super.key,
    required this.title,
    required this.slivers,
    this.subtitle,
    this.actions,
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final List<Widget> slivers;
  final List<Widget>? actions;

  /// Pinned over the bottom of the content, such as [PinnedActions] or a
  /// `GlassBar`.
  final Widget? bottom;

  /// Taller than Material's 64, so the large title has room to breathe.
  static const _barHeight = 72.0;

  /// Room for the back button, inset from the screen edge.
  static const _leadingWidth = 64.0;

  /// Without a back button, the title lines up with section headers.
  static const _titleInset = Insets.lPlus;

  static const _barShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(
      bottom: Radius.circular(Corners.extraLarge),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // The same test AppBar uses to imply a back button.
    final canPop = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
    final subtitle = this.subtitle;

    return PageFrame(
      appBar: AppBar(
        toolbarHeight: _barHeight,
        automaticallyImplyLeading: false,
        leadingWidth: canPop ? _leadingWidth : null,
        leading: canPop
            ? Padding(
                padding: const EdgeInsets.only(left: Insets.s),
                child: Center(
                  child: BackButton(
                    // Material 3's filled tonal icon button colours.
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.secondaryContainer,
                      foregroundColor: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
              )
            : null,
        titleSpacing: canPop ? Insets.s : _titleInset,
        // Transparent at rest; a translucent surface once content scrolls
        // underneath. The surface colour at zero opacity, rather than plain
        // transparent, keeps the status bar icons' contrast right.
        backgroundColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.scrolledUnder)
              ? context.glass.barFill
              : scheme.surface.withValues(alpha: 0),
        ),
        scrolledUnderElevation: 0,
        shape: _barShape,
        clipBehavior: Clip.antiAlias,
        flexibleSpace: const _Frost(shape: _barShape),
        title: subtitle == null
            ? Text(title)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
        actions: actions,
      ),
      bottom: bottom,
      slivers: slivers,
    );
  }
}

/// Frosts whatever scrolls behind the top bar. Follows the same scroll
/// signal the bar uses for its scrolled-under colour, and only blurs then:
/// at rest there's nothing to frost, and the blur would soften the page
/// background along the bar's lower edge.
class _Frost extends StatefulWidget {
  const _Frost({required this.shape});

  /// The bar's shape. A backdrop filter blurs everything up to its nearest
  /// clip, and the bar's own clip doesn't bound it, so the frost clips
  /// itself.
  final ShapeBorder shape;

  @override
  State<_Frost> createState() => _FrostState();
}

class _FrostState extends State<_Frost> {
  ScrollNotificationObserverState? _observer;
  bool _scrolledUnder = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _observer?.removeListener(_onScroll);
    _observer = ScrollNotificationObserver.maybeOf(context)
      ?..addListener(_onScroll);
  }

  @override
  void dispose() {
    _observer?.removeListener(_onScroll);
    super.dispose();
  }

  // As AppBar decides it: the page's own vertical scroll view, with
  // content before the visible part.
  void _onScroll(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification ||
        !defaultScrollNotificationPredicate(notification)) {
      return;
    }
    final metrics = notification.metrics;
    final scrolledUnder = switch (metrics.axisDirection) {
      AxisDirection.down => metrics.extentBefore > 0,
      AxisDirection.up => metrics.extentAfter > 0,
      _ => _scrolledUnder,
    };
    if (scrolledUnder != _scrolledUnder) {
      setState(() => _scrolledUnder = scrolledUnder);
    }
  }

  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: ShapeBorderClipper(shape: widget.shape),
    child: BackdropFilter(
      enabled: _scrolledUnder,
      filter: GlassFilters.bar,
      child: const SizedBox.expand(),
    ),
  );
}
