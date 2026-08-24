import 'package:flutter/material.dart';

/// Farb- und Schriftschema der App.
///
/// Bisher lief alles auf `ColorScheme.fromSeed(seedColor: Colors.green)` und
/// damit auf Material-Standard ohne eigenes Gesicht. Zwei Dinge geben hier den
/// Ausschlag:
///
/// 1. Bedient wird auf einem Tablet, im Stehen, mit Armlaenge Abstand und
///    manchmal nassen Fingern. Deshalb groessere Schaltflaechen, kraeftigere
///    Zahlen und mehr Abstand als im Material-Standard.
/// 2. Im Vereinsheim wird abends bei gedaempftem Licht bedient. Der dunkle
///    Modus ist deshalb kein Zierrat, sondern am Abend der Normalfall.
///
/// Bewusst ohne eigene Schriftdatei: eine per Netz nachgeladene Schrift waere
/// bei wackeligem WLAN ein Ausfallrisiko, eine mitgelieferte blaeht das Paket
/// auf. Stattdessen ist die Systemschrift durchgaengig auf Groesse, Gewicht
/// und Laufweite abgestimmt.
class AppTheme {
  AppTheme._();

  /// Kieferngruen - Vereinsfarbe und ruhig genug, um stundenlang davor zu
  /// stehen.
  static const seed = Color(0xFF2E6B4F);

  /// Warmes Ocker als Gegenpol: Hinweise, Hervorhebungen, offene Betraege.
  static const ochreLight = Color(0xFF8A6410);
  static const ochreDark = Color(0xFFD9AE55);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final base = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final scheme = base.copyWith(
      secondary: isDark ? ochreDark : ochreLight,
      // Leicht ins Gruene gezogene Neutraltoene statt reinem Grau - sonst
      // wirken die Flaechen neben dem Akzent kalt.
      surface: isDark ? const Color(0xFF141917) : const Color(0xFFFBFCFA),
      surfaceContainerHighest:
          isDark ? const Color(0xFF222A26) : const Color(0xFFEDF1EE),
    );

    final text = _typography(scheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text,

      // Etwas luftiger als der Standard - der Finger ist ungenauer als die Maus.
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: scheme.surfaceTint,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: isDark ? const Color(0xFF1B2320) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),

      // Mindesthoehe 52: kleiner wird es auf einem Tablet im Betrieb fummelig.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 48),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1B2320) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),

      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 10,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(0, 48),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }

  /// Schriftstufen fuer Bedienung auf Armlaenge.
  ///
  /// Betraege und Mengen tragen `tabular figures`, damit Ziffern in Listen
  /// untereinander stehen und beim Ueberfliegen nicht springen.
  static TextTheme _typography(ColorScheme scheme) {
    const tabular = [FontFeature.tabularFigures()];
    return TextTheme(
      displaySmall: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.5, fontFeatures: tabular, color: scheme.onSurface),
      headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: scheme.onSurface),
      headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: scheme.onSurface),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: scheme.onSurface),
      titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: scheme.onSurface),
      bodyLarge: TextStyle(fontSize: 16, height: 1.35, fontFeatures: tabular, color: scheme.onSurface),
      bodyMedium: TextStyle(fontSize: 15, height: 1.35, fontFeatures: tabular, color: scheme.onSurface),
      bodySmall: TextStyle(fontSize: 13, height: 1.3, color: scheme.onSurfaceVariant),
      labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: scheme.onSurface),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: scheme.onSurfaceVariant),
    );
  }
}
