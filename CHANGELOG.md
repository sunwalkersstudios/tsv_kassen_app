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

### Zugang und Rollen

- **Die fehlenden Admin-Functions gibt es jetzt.** `adminListUsers`,
  `adminCreateUser`, `adminSetRole`, `adminSetPassword` und `adminDisableUser`
  wurden von der App seit jeher aufgerufen, existierten aber nie - die
  Nutzerverwaltung lief ins Leere.
- **Die Rolle liegt in den Custom Claims des Auth-Tokens**, nicht mehr in
  `users/{uid}.role`. Ein Nutzer kann seine Claims nicht selbst schreiben; das
  kann allein das Backend. Damit ist die Selbstbefoerderung zum Admin zu.
- **Der Login legt keine Konten mehr an.** Die Notloesung "Konto anlegen und
  Rolle aus dem E-Mail-Praefix raten" ist entfernt. Zugaenge vergibt der Admin.
- **Verstaendliche Anmeldefehler** statt roher FirebaseAuthException; bei
  falschen Zugangsdaten ohne Hinweis darauf, ob die Adresse existiert.
- **PIN als Rueckfallebene zur Biometrie.** Ohne Fingerabdrucksensor entsperrte
  sich der Sperrbildschirm bisher selbst. Die PIN gilt pro Geraet und wird nur
  als gesalzener SHA-256-Wert abgelegt. Verwaltung unter Admin -> Einstellungen.

### Firestore-Regeln

- `role()` liest aus dem Token statt per `get()` aus `users/{uid}` - schliesst
  die Selbstbefoerderung aus und spart einen Dokumentlesevorgang je Auswertung.
- `users/{uid}`: eigene Aenderungen nur noch an Anzeigename und Push-Token;
  Rolle und Sperrstatus setzt ausschliesslich das Backend.
- Positionen bezahlter Tickets sind gesperrt - vorher war das Ticket
  unveraenderlich, seine Positionen aber nicht.
- `sales`: Einzelabruf fuer Kellner (zum Belegdruck), Auflisten nur fuer Admin.
  Vorher konnte jede Aushilfe saemtliche Tagesumsaetze lesen.

### Aufgeraeumt

- `repo/org_repo.dart` und `models/organization.dart` entfernt - hingen am
  bereits geloeschten Onboarding und enthielten einen weiteren Pfad, der Konten
  anlegte.

### Geld: durchgaengig ganzzahlige Cent

- **Alle Betraege laufen als `int` in Cent.** Fliesskomma war die falsche
  Grundlage: 0,10 + 0,20 ergibt dort nicht exakt 0,30, und der Fehler waechst
  mit jeder Summierung ueber die Positionen eines Belegs.
- Umgestellt: Menuepreise (`priceCents`), Ticketpositionen, Belegsummen
  (`totalCents`, `lineTotalCents`), offene Betraege je Tisch, Kassenwerte.
- **Ein zentraler Leser** in `Money` kennt beide Feldnamen und faellt auf das
  alte Fliesskommafeld zurueck. So bleiben nicht migrierte Dokumente lesbar,
  statt stillschweigend 0,00 EUR zu ergeben - und die Rueckfalllogik liegt an
  einer Stelle statt verstreut.
- Die 43 vorhandenen Menuepreise wurden migriert; `price` bleibt vorerst als
  Ruecksprungmoeglichkeit stehen.
- `Money.parse` deutet einen Punkt mit genau drei Ziffern dahinter als
  Tausendertrenner ("1.000" -> 1000,00), sonst als Dezimaltrenner.
- Betraege erscheinen jetzt durchgaengig mit deutschem Dezimalkomma, auch auf
  gedruckten Belegen.

### Behoben

- **Der gedruckte Tagesabschluss zeigte 0,00 EUR bei Kassenstart, Einlagen und
  Entnahmen.** `printDaySummary` las diese Werte noch aus SharedPreferences,
  waehrend sie seit der Kassenueberarbeitung in Firestore liegen - die App
  zeigte also andere Zahlen als der Bon.

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
