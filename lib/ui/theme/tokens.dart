import 'package:flutter/widgets.dart';

/// Spacing scale. Layouts use these instead of raw numbers.
abstract final class Insets {
  static const double xxs = 2;
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;

  // Half steps, for spots the main steps don't fit.
  static const double xsPlus = 6;
  static const double mPlus = 14;
  static const double lPlus = 20;
  static const double xxl = 32;

  /// Horizontal padding of every page.
  static const page = EdgeInsets.symmetric(horizontal: l);

  /// Padding inside cards and grouped lists.
  static const card = EdgeInsets.all(l);

  /// The gap between segments of a group, which lets the surface show
  /// through as a hairline.
  static const double segment = 3;
}

/// Corner radii.
abstract final class Corners {
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;
  static const double extraLarge = 24;
  static const double hero = 28;

  static const smallRadius = BorderRadius.all(Radius.circular(small));
  static const mediumRadius = BorderRadius.all(Radius.circular(medium));
  static const largeRadius = BorderRadius.all(Radius.circular(large));
  static const extraLargeRadius = BorderRadius.all(Radius.circular(extraLarge));
  static const heroRadius = BorderRadius.all(Radius.circular(hero));

  /// Where segments of a group meet: rows in a group, buttons in a button
  /// group.
  static const double segment = small - 2;
}

/// Fixed sizes shared by several components.
abstract final class Sizes {
  static const double iconSmall = 18;
  static const double icon = 24;
  static const double badge = 40;
  static const double badgeLarge = 56;
  static const double illustration = 88;

  /// Minimum height of controls floating over content, the navigation bar
  /// and buttons pinned over a page, so they match. Material 3's floating
  /// toolbar height.
  static const double floatingControl = 64;
}

/// How faint a disabled control is: Material's 38%.
const double disabledOpacity = 0.38;
