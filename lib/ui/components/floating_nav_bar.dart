import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/glass_colors.dart';
import '../theme/glass_filters.dart';
import '../theme/tokens.dart';

@immutable
class FloatingNavDestination {
  const FloatingNavDestination({
    required this.icon,
    required this.label,
    this.showBadge = false,
  });

  /// Outlined; only its colour changes when selected.
  final IconData icon;
  final String label;

  /// A small dot on the icon, for something that needs attention.
  final bool showBadge;
}

/// A frosted, pill-shaped navigation bar floating above the content: what
/// scrolls underneath shows through, blurred. One accent
/// pill sits behind the items and slides to the selected one. Built from
/// Material 3 colours and shapes, since Material's floating toolbar isn't
/// in Flutter yet.
///
/// Place it in a `Scaffold` with `extendBody: true`, so content scrolls
/// behind it. The scaffold then includes the bar's height in the body's
/// bottom padding, for scrolling content to keep clear of it.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<FloatingNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _itemWidth = 100.0;
  static const _inset = 4.0;
  static const _slide = Duration(milliseconds: 380);

  /// Material 3's emphasized curve: quick start, long gentle settle.
  static const _curve = Cubic(0.2, 0, 0, 1);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glass = context.glass;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: Insets.m),
      child: Center(
        heightFactor: 1,
        // The shadow sits outside the clip; the blur and fill inside it.
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: const StadiumBorder(),
            shadows: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipPath(
            clipper: const ShapeBorderClipper(shape: StadiumBorder()),
            child: BackdropFilter(
              filter: GlassFilters.bar,
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: Sizes.floatingControl,
                ),
                padding: const EdgeInsets.all(_inset),
                decoration: ShapeDecoration(
                  color: glass.barFill,
                  shape: StadiumBorder(side: BorderSide(color: glass.edge)),
                ),
                child: SizedBox(
                  width: _itemWidth * destinations.length,
                  child: Stack(
                    children: [
                      AnimatedPositioned(
                        duration: _slide,
                        curve: _curve,
                        left: _itemWidth * selectedIndex,
                        top: 0,
                        bottom: 0,
                        width: _itemWidth,
                        child: DecoratedBox(
                          decoration: ShapeDecoration(
                            color: scheme.primaryContainer,
                            shape: StadiumBorder(
                              side: BorderSide(
                                color: scheme.primary.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < destinations.length; i++)
                            _Item(
                              destination: destinations[i],
                              selected: i == selectedIndex,
                              onTap: () {
                                // A light tick when the selection changes; the
                                // current tab stays silent.
                                if (i != selectedIndex) {
                                  HapticFeedback.selectionClick();
                                }
                                onSelected(i);
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final FloatingNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // No ripple: the sliding pill is the feedback, and a highlight on the
    // tapped item would flash ahead of it.
    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: FloatingNavBar._itemWidth,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Insets.xsPlus),
            // The label follows the sliding pill, lighting up as it arrives.
            // The icon only switches colour; nothing about it animates.
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: selected ? 1 : 0),
              duration: FloatingNavBar._slide,
              curve: FloatingNavBar._curve,
              child: Badge(
                isLabelVisible: destination.showBadge,
                smallSize: 8,
                child: Icon(
                  destination.icon,
                  size: 22,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
              builder: (context, t, icon) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon!,
                  const SizedBox(height: Insets.xxs),
                  Text(
                    destination.label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Color.lerp(
                        scheme.onSurfaceVariant,
                        scheme.primary,
                        t,
                      ),
                      fontWeight: FontWeight.lerp(
                        FontWeight.w500,
                        FontWeight.w700,
                        t,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
