# Changelog

## Unveroeffentlicht

### Kasse: Kassenschnitte dauerhaft verfuegbar

- **Zeitraum frei waehlbar.** Die bisherige Liste der letzten sieben Tage ist
  ersetzt durch Tag / Woche / Monat / Jahr, Blaetterpfeile und einen Kalender,
  der bis zum ersten Verkaufstag zurueckreicht.
- **Kassenstart, Einlagen und Entnahmen liegen in Firestore** unter
  `cashDays/{yyyy-MM-dd}` statt in SharedPreferences. Damit sind sie auf jedem
  Geraet sichtbar und ueberstehen eine Neuinstallation. Zusaetzlich ein
  Notizfeld je Tag.
- **Export als Datei statt Zwischenablage.** PDF mit Deckkopf, Kennzahlen,
  Kassenbestand, Tages- und Artikelauswertung sowie CSV fuer deutsches Excel -
  beides ueber den Teilen-Dialog des Geraets.
- Mehrtagesansichten zeigen zusaetzlich eine Aufschluesselung nach Tagen;
  ein Tippen darauf springt in den Einzeltag.

### Geld

- Neue Betraege werden als ganzzahlige Cent gefuehrt (`Money`, `CashDay`),
  nicht als Fliesskommazahl. Die Verkaufsdokumente bleiben vorerst `double`;
  umgerechnet wird beim Einlesen.
- `Money.parse` deutet einen Punkt mit genau drei Ziffern dahinter als
  Tausendertrenner ("1.000" -> 1000,00), sonst als Dezimaltrenner.

### Sonstiges

- Deutsche Lokalisierung: `flutter_localizations`, Datumssymbole werden beim
  Start geladen. Der Kalender erscheint dadurch auf Deutsch.
- Firestore-Regeln fuer `cashDays`: nur Admin, Betraege muessen ganzzahlig und
  nicht negativ sein, Loeschen ist ausgeschlossen.
- 24 Unit-Tests fuer Zeitraumlogik, Betragsrechnung und Auswertung.

## 1.0.2+4 — 2025-10-27

- Build stabilisiert und Lint-Probleme behoben
  - use_build_context_synchronously in mehreren Screens gefixt (Admin*, Cashier, Order)
  - Deprecated `.withOpacity(...)` durch `.withValues(alpha: ...)` ersetzt (TablePlan)
- Dependency-Upgrades
  - firebase_core ^4.2.0, firebase_auth ^6.1.1, cloud_firestore ^6.0.3, firebase_messaging ^16.0.3
  - firebase_crashlytics ^5.0.3, firebase_performance ^0.11.1+1
  - go_router 16.3.0, local_auth 3.0.0
- Tests/Analyse/Build
  - `flutter analyze`: keine Fehler
  - `flutter test`: grün (+1)
  - Release-Build (APK) erfolgreich

Hinweis: Weitere optionale Upgrades (z. B. flutter_local_notifications, lints) sind möglich, aber nicht Teil dieses Freeze-Releases.
