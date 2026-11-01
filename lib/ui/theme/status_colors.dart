import 'package:material_ui/material_ui.dart';

/// The meaning a status carries, which decides its colours.
enum StatusTone {
  /// Plain information, no particular state.
  neutral,

  /// Something is happening right now (running, connected).
  active,

  /// All good (delivered, allowed).
  healthy,

  /// Worth knowing, nothing to do (queued, no signal).
  warning,

  /// Needs the user (refused, failing).
  error,
}

/// The colours for one [StatusTone].
@immutable
class ToneColors {
  const ToneColors({
    required this.container,
    required this.onContainer,
    required this.accent,
    required this.onAccent,
  });

  /// Background of cards and chips in this tone.
  final Color container;

  /// Text and icons on [container].
  final Color onContainer;

  /// Strong colour: icon circles, filled chips, buttons.
  final Color accent;

  /// Text and icons on [accent].
  final Color onAccent;
}

/// Status colours as a theme extension. Active and healthy follow the
/// dynamic colour scheme; warning and error keep fixed hues, so they read
/// the same whatever the wallpaper.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.neutral,
    required this.active,
    required this.healthy,
    required this.warning,
    required this.error,
  });

  factory StatusColors.from(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    return StatusColors(
      neutral: ToneColors(
        container: scheme.surfaceContainerHigh,
        onContainer: scheme.onSurfaceVariant,
        accent: scheme.outline,
        onAccent: scheme.surface,
      ),
      active: ToneColors(
        container: scheme.primaryContainer,
        onContainer: scheme.onPrimaryContainer,
        accent: scheme.primary,
        onAccent: scheme.onPrimary,
      ),
      healthy: ToneColors(
        container: scheme.primaryContainer,
        onContainer: scheme.onPrimaryContainer,
        accent: scheme.primary,
        onAccent: scheme.onPrimary,
      ),
      warning: dark
          ? const ToneColors(
              container: Color(0xFF4A3812),
              onContainer: Color(0xFFFFE2B0),
              accent: Color(0xFFF2C46B),
              onAccent: Color(0xFF3F2C00),
            )
          : const ToneColors(
              container: Color(0xFFFFE8BC),
              onContainer: Color(0xFF3F2C00),
              accent: Color(0xFF9A6400),
              onAccent: Color(0xFFFFFFFF),
            ),
      error: dark
          ? const ToneColors(
              container: Color(0xFF66261F),
              onContainer: Color(0xFFFFDAD5),
              accent: Color(0xFFFFB4AA),
              onAccent: Color(0xFF5F1410),
            )
          : const ToneColors(
              container: Color(0xFFFFDAD5),
              onContainer: Color(0xFF5F1410),
              accent: Color(0xFFB3261E),
              onAccent: Color(0xFFFFFFFF),
            ),
    );
  }

  final ToneColors neutral;
  final ToneColors active;
  final ToneColors healthy;
  final ToneColors warning;
  final ToneColors error;

  ToneColors operator [](StatusTone tone) => switch (tone) {
    StatusTone.neutral => neutral,
    StatusTone.active => active,
    StatusTone.healthy => healthy,
    StatusTone.warning => warning,
    StatusTone.error => error,
  };

  @override
  StatusColors copyWith({
    ToneColors? neutral,
    ToneColors? active,
    ToneColors? healthy,
    ToneColors? warning,
    ToneColors? error,
  }) => StatusColors(
    neutral: neutral ?? this.neutral,
    active: active ?? this.active,
    healthy: healthy ?? this.healthy,
    warning: warning ?? this.warning,
    error: error ?? this.error,
  );

  @override
  StatusColors lerp(StatusColors? other, double t) {
    if (other == null) return this;
    ToneColors mix(ToneColors a, ToneColors b) => ToneColors(
      container: Color.lerp(a.container, b.container, t)!,
      onContainer: Color.lerp(a.onContainer, b.onContainer, t)!,
      accent: Color.lerp(a.accent, b.accent, t)!,
      onAccent: Color.lerp(a.onAccent, b.onAccent, t)!,
    );
    return StatusColors(
      neutral: mix(neutral, other.neutral),
      active: mix(active, other.active),
      healthy: mix(healthy, other.healthy),
      warning: mix(warning, other.warning),
      error: mix(error, other.error),
    );
  }
}

extension StatusColorsContext on BuildContext {
  /// The colours for [tone] in the current theme.
  ToneColors tone(StatusTone tone) =>
      Theme.of(this).extension<StatusColors>()![tone];
}
