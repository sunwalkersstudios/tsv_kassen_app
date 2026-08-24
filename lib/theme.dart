import 'package:flutter/material.dart';

/// Farb- und Schriftschema der App - Richtung "Wirtshaus modern".
///
/// Der erste Anlauf war ein sauber abgestimmtes Material-Standardschema und sah
/// entsprechend aus: korrekt, aber nach Formular. Eine Kasse im Vereinsheim
/// steht neben Schnitzel und Bier, nicht im Buero.
///
/// Drei Entscheidungen tragen den Entwurf:
///
/// 1. **Warme statt neutraler Grundtoene.** Kein reines Grau und kein
///    Klinikweiss, sondern Papierweiss mit Gelbstich und ein Espressoschwarz
///    mit Braunanteil. Neutralgrau neben einem warmen Akzent wirkt schmutzig.
/// 2. **Kupfer als Leitfarbe.** Bier, Braten, Holz - die Farbwelt des Hauses,
///    und kraeftig genug, um auf beiden Gruenden zu tragen. Kraeutergruen
///    bleibt daneben ausschliesslich fuer "fertig" reserviert, damit ein
///    Farbsignal in der Kueche auch wirklich etwas bedeutet.
/// 3. **Zahlen sind die Hauptsache.** Betraege und Tischnummern gross, fett
///    und mit tabellarischen Ziffern. Wer im Stehen abkassiert, liest Zahlen,
///    keine Fliesstexte.
///
/// Bewusst ohne eigene Schriftdatei: eine per Netz nachgeladene waere bei
/// wackeligem WLAN ein Ausfallrisiko, eine mitgelieferte blaeht das Paket auf.
class AppTheme {
  AppTheme._();

  // --------------------------------------------------------------- Palette

  /// Kupfer - Leitfarbe.
  static const copper = Color(0xFFC9762D);
  static const copperDeep = Color(0xFF9A5618);
  static const copperSoftLight = Color(0xFFF6E7D6);
  static const copperSoftDark = Color(0xFF3A2A18);

  /// Kraeutergruen - ausschliesslich fuer "fertig" und Bestaetigungen.
  static const herb = Color(0xFF5A8C4E);
  static const herbDark = Color(0xFF86BE78);

  /// Warnton fuer Wartezeiten und offene Betraege.
  static const amber = Color(0xFFD9A441);

  /// Storno, Fehler, Loeschen.
  static const brick = Color(0xFFB4453B);
  static const brickDark = Color(0xFFE58A80);

  // Gruende und Flaechen
  static const _paper = Color(0xFFFAF6F0); // warmes Papierweiss
  static const _paperCard = Color(0xFFFFFFFF);
  static const _paperSunken = Color(0xFFF1EAE0);
  static const _inkLight = Color(0xFF241D15);
  static const _inkLightMuted = Color(0xFF78695A);
  static const _lineLight = Color(0xFFE3D9CB);

  static const _espresso = Color(0xFF17130E); // warmes Schwarz mit Braunanteil
  static const _espressoCard = Color(0xFF221C15);
  static const _espressoRaised = Color(0xFF2C251C);
  static const _inkDark = Color(0xFFF5EFE6);
  static const _inkDarkMuted = Color(0xFFA79A88);
  static const _lineDark = Color(0xFF393025);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  /// Wie [light]/[dark], aber mit ausdruecklich benannter Schrift.
  ///
  /// Nur fuer die kopflose Entwurfsvorschau gedacht: dort gibt es keine
  /// Systemschrift, und Text ohne benannte Familie wird als Kaestchen
  /// gezeichnet. Im Betrieb waehlt Flutter die Systemschrift selbst.
  static ThemeData preview(Brightness b, String fontFamily) =>
      _build(b, fontFamily: fontFamily);

  static ColorScheme _scheme(Brightness b) {
    final isDark = b == Brightness.dark;
    // Ausdruecklich gesetzt statt aus einem Seed abgeleitet: fromSeed
    // verschiebt die Toene ins Neutrale und nimmt der Palette genau die
    // Waerme, auf die es hier ankommt.
    return isDark
        ? const ColorScheme.dark(
            primary: copper,
            onPrimary: Color(0xFF1B1208),
            primaryContainer: copperSoftDark,
            onPrimaryContainer: Color(0xFFF0C79B),
            secondary: herbDark,
            onSecondary: Color(0xFF101A0D),
            secondaryContainer: Color(0xFF1F2E1B),
            onSecondaryContainer: Color(0xFFBDE0B2),
            tertiary: amber,
            onTertiary: Color(0xFF1F1704),
            error: brickDark,
            onError: Color(0xFF23100D),
            errorContainer: Color(0xFF3A1B17),
            onErrorContainer: Color(0xFFF3B8B1),
            surface: _espresso,
            onSurface: _inkDark,
            onSurfaceVariant: _inkDarkMuted,
            surfaceContainerLowest: _espresso,
            surfaceContainer: _espressoCard,
            surfaceContainerHighest: _espressoRaised,
            outline: Color(0xFF4C4133),
            outlineVariant: _lineDark,
          )
        : const ColorScheme.light(
            primary: copperDeep,
            onPrimary: Color(0xFFFFFFFF),
            primaryContainer: copperSoftLight,
            onPrimaryContainer: Color(0xFF4A2A0B),
            secondary: herb,
            onSecondary: Color(0xFFFFFFFF),
            secondaryContainer: Color(0xFFDDEBD8),
            onSecondaryContainer: Color(0xFF23361E),
            tertiary: Color(0xFF9A7318),
            onTertiary: Color(0xFFFFFFFF),
            error: brick,
            onError: Color(0xFFFFFFFF),
            errorContainer: Color(0xFFF7DEDB),
            onErrorContainer: Color(0xFF5A1A14),
            surface: _paper,
            onSurface: _inkLight,
            onSurfaceVariant: _inkLightMuted,
            surfaceContainerLowest: _paperCard,
            surfaceContainer: _paperCard,
            surfaceContainerHighest: _paperSunken,
            outline: Color(0xFFC4B7A5),
            outlineVariant: _lineLight,
          );
  }

  static ThemeData _build(Brightness brightness, {String? fontFamily}) {
    final isDark = brightness == Brightness.dark;
    final scheme = _scheme(brightness);
    final text = _typography(scheme, fontFamily);
    final cardColor = isDark ? _espressoCard : _paperCard;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.headlineSmall,
        shape: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),

      // 56 Pixel Mindesthoehe: bedient wird im Stehen, oft in Eile.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          textStyle: TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          side: BorderSide(color: scheme.outline),
          textStyle: TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 48),
          textStyle: TextStyle(fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),

      chipTheme: ChipThemeData(
        labelStyle: TextStyle(fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? _espressoRaised : _paperCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),

      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 12,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      // Ausgewaehltes Segment in Kupfer, nicht im Standardgruen von Material:
      // Gruen ist in dieser App fuer "fertig" reserviert. Traegt es auch eine
      // blosse Auswahl, bedeutet ein gruenes Signal in der Kueche nichts mehr.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(0, 52),
          selectedBackgroundColor: scheme.primaryContainer,
          selectedForegroundColor: scheme.onPrimaryContainer,
          textStyle: TextStyle(fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  /// Schriftstufen fuer Bedienung auf Armlaenge.
  ///
  /// Betraege, Mengen und Tischnummern tragen tabellarische Ziffern, damit
  /// Zahlen in Listen untereinander stehen und beim Ueberfliegen nicht springen.
  static TextTheme _typography(ColorScheme scheme, [String? f]) {
    const tabular = [FontFeature.tabularFigures()];
    return TextTheme(
      displayLarge: TextStyle(fontFamily: f, fontSize: 52, fontWeight: FontWeight.w800, letterSpacing: -1.4, height: 1.12, fontFeatures: tabular, color: scheme.onSurface),
      displayMedium: TextStyle(fontFamily: f, fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1.0, height: 1.05, fontFeatures: tabular, color: scheme.onSurface),
      displaySmall: TextStyle(fontFamily: f, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.7, fontFeatures: tabular, color: scheme.onSurface),
      headlineMedium: TextStyle(fontFamily: f, fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: scheme.onSurface),
      headlineSmall: TextStyle(fontFamily: f, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: scheme.onSurface),
      titleLarge: TextStyle(fontFamily: f, fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.1, color: scheme.onSurface),
      titleMedium: TextStyle(fontFamily: f, fontSize: 16, fontWeight: FontWeight.w700, color: scheme.onSurface),
      bodyLarge: TextStyle(fontFamily: f, fontSize: 16, height: 1.35, fontFeatures: tabular, color: scheme.onSurface),
      bodyMedium: TextStyle(fontFamily: f, fontSize: 15, height: 1.35, fontFeatures: tabular, color: scheme.onSurface),
      bodySmall: TextStyle(fontFamily: f, fontSize: 13, height: 1.3, color: scheme.onSurfaceVariant),
      labelLarge: TextStyle(fontFamily: f, fontSize: 15, fontWeight: FontWeight.w700, color: scheme.onSurface),
      labelMedium: TextStyle(fontFamily: f, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: scheme.onSurfaceVariant),
      labelSmall: TextStyle(fontFamily: f, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: scheme.onSurfaceVariant),
    );
  }
}
