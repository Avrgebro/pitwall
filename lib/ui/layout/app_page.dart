import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

import '../components/floating_nav_bar.dart';
import '../theme/tokens.dart';

/// The frame of every screen: a title (with a back button on sub-screens),
/// an optional subtitle, and scrolling content with page padding.
///
/// Content scrolls under the top bar. The bar is transparent at the top of
/// the page and fills in, frosted and with rounded bottom corners, once
/// content passes beneath it.
class AppPage extends StatefulWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.actions,
    this.floatingActionButton,
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  /// Pinned below the content, such as an input bar or a main button.
  /// Kept clear of the system navigation bar; no `SafeArea` needed.
  final Widget? bottom;

  @override
  State<AppPage> createState() => _AppPageState();
}

class _AppPageState extends State<AppPage> {
  static const _barHeight = 72.0;
  static const _barRadius = BorderRadius.vertical(
    bottom: Radius.circular(Corners.extraLarge),
  );

  /// Whether content has scrolled under the top bar. The blur only runs
  /// then: at rest it would smudge the page edge just below the bar.
  bool _scrolledUnder = false;

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    final scrolled = notification.metrics.extentBefore > 0;
    if (scrolled != _scrolledUnder) setState(() => _scrolledUnder = scrolled);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canPop = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
    final topInset = MediaQuery.paddingOf(context).top;
    final subtitle = widget.subtitle;
    final bottom = widget.bottom;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        toolbarHeight: _barHeight,
        automaticallyImplyLeading: false,
        leadingWidth: canPop ? 64 : null,
        leading: canPop
            ? Padding(
                padding: const EdgeInsets.only(left: Insets.s),
                child: Center(
                  child: IconButton.filledTonal(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: MaterialLocalizations.of(context)
                        .backButtonTooltip,
                  ),
                ),
              )
            : null,
        titleSpacing: canPop ? Insets.s : Insets.l + 4,
        // Transparent at rest; a translucent surface once content scrolls
        // underneath.
        backgroundColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.scrolledUnder)
              ? scheme.surfaceContainer.withValues(alpha: 0.82)
              : scheme.surface.withValues(alpha: 0),
        ),
        scrolledUnderElevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: _barRadius),
        clipBehavior: Clip.antiAlias,
        // Frosts whatever scrolls behind the bar.
        flexibleSpace: ClipRRect(
          borderRadius: _barRadius,
          child: BackdropFilter(
            enabled: _scrolledUnder,
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: const SizedBox.expand(),
          ),
        ),
        title: subtitle == null
            ? Text(widget.title)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
        actions: widget.actions,
      ),
      floatingActionButton: widget.floatingActionButton,
      body: Column(
        children: [
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  Insets.l,
                  topInset + _barHeight + Insets.s,
                  Insets.l,
                  // Room for the floating navigation bar on tab pages;
                  // pages with their own bottom area don't have one.
                  bottom == null
                      ? FloatingNavBar.clearance + Insets.l
                      : Insets.l,
                ),
                children: widget.children,
              ),
            ),
          ),
          // Bottom only: the top inset includes the top bar, which content
          // already scrolls under.
          if (bottom != null) SafeArea(top: false, child: bottom),
        ],
      ),
    );
  }
}
