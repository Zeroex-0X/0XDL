import 'package:flutter/material.dart';

/// Colours generated from an accent hue, for both day and night.
class AppPalette {
  final Color bg, card, primary, primarySoft, accent, accent2, textDim, border;
  const AppPalette({
    required this.bg,
    required this.card,
    required this.primary,
    required this.primarySoft,
    required this.accent,
    required this.accent2,
    required this.textDim,
    required this.border,
  });

  factory AppPalette.generate(double hue, Brightness b) {
    Color hsl(double h, double s, double l) =>
        HSLColor.fromAHSL(1, h % 360, s, l).toColor();
    if (b == Brightness.dark) {
      final primary = hsl(hue, .75, .60);
      return AppPalette(
        bg: hsl(hue, .40, .09),
        card: hsl(hue, .34, .15),
        primary: primary,
        primarySoft: primary.withAlpha(0x38),
        accent: hsl(hue, .85, .78),
        accent2: hsl(hue + 35, .80, .80),
        textDim: hsl(hue, .16, .64),
        border: hsl(hue, .34, .22),
      );
    }
    final primary = hsl(hue, .72, .46);
    return AppPalette(
      bg: hsl(hue, .60, .96),
      card: Colors.white,
      primary: primary,
      primarySoft: primary.withAlpha(0x30),
      accent: hsl(hue, .78, .52),
      accent2: hsl(hue + 35, .62, .60),
      textDim: hsl(hue, .18, .40),
      border: hsl(hue, .45, .90),
    );
  }

  static AppPalette of(BuildContext c) =>
      Theme.of(c).extension<PaletteExt>()!.p;
}

class PaletteExt extends ThemeExtension<PaletteExt> {
  final AppPalette p;
  const PaletteExt(this.p);

  @override
  PaletteExt copyWith({AppPalette? p}) => PaletteExt(p ?? this.p);

  @override
  PaletteExt lerp(ThemeExtension<PaletteExt>? other, double t) =>
      other is PaletteExt ? (t < 0.5 ? this : other) : this;
}

/// Colour choices shown in Settings > Themes. Index 0 matches the app icon.
const kAccentHues = <double>[207, 262, 150, 36, 340, 185];

ThemeData buildTheme(Brightness b, int accent) {
  final hue = kAccentHues[accent.clamp(0, kAccentHues.length - 1)];
  final p = AppPalette.generate(hue, b);
  final scheme = ColorScheme.fromSeed(seedColor: p.primary, brightness: b)
      .copyWith(primary: p.primary, secondary: p.accent, surface: p.card);
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    extensions: [PaletteExt(p)],
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
  );
}
