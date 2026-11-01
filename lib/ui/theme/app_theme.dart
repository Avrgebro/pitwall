import 'package:material_ui/material_ui.dart';

import 'status_colors.dart';
import 'tokens.dart';

/// Pitwall's Material 3 theme. Colours come from the wallpaper when Android
/// offers them (dynamic colour), with teal as the fallback seed.
abstract final class AppTheme {
  static const seed = Color(0xFF006A6A);

  static ThemeData light([ColorScheme? dynamic]) =>
      _build(_scheme(dynamic, Brightness.light));

  static ThemeData dark([ColorScheme? dynamic]) =>
      _build(_scheme(dynamic, Brightness.dark));

  // Dynamic schemes from older Android versions can lack the newer surface
  // roles, so the full scheme is rebuilt from their primary colour.
  static ColorScheme _scheme(ColorScheme? dynamic, Brightness brightness) =>
      ColorScheme.fromSeed(
        seedColor: dynamic?.primary ?? seed,
        brightness: brightness,
      );

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(colorScheme: scheme);
    // ThemeData.textTheme only carries colours; sizes are added later by
    // Theme. Styles set here need both, so the 2021 geometry is merged in.
    final text = Typography.englishLike2021.merge(base.textTheme);
    return base.copyWith(
      extensions: [StatusColors.from(scheme)],
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: text.headlineSmall?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: Corners.extraLargeRadius,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: Insets.l),
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: text.bodyLarge?.copyWith(color: scheme.onSurface),
        subtitleTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: Corners.smallRadius),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: Corners.smallRadius),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      switchTheme: SwitchThemeData(
        thumbIcon: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const Icon(Icons.check)
              : null,
        ),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        shape: Border(),
        collapsedShape: Border(),
      ),
    );
  }
}
