# TSV KassenApp

Flutter-basierte Kassen-/Bestell-App für das Vereinsheim-Restaurant.

Aktueller Stand: Produktiver Kern mit Firebase (Auth/Firestore/FCM), rollenbasiertem Routing (go_router), stabilem Tischplan (Firestore), serverpersistenten Tickets/Verkäufen, Ready-Flow Küche/Bar, Kassenübersicht inkl. Tagesabschlussdruck und flexiblem Drucksystem (ESC/POS für Bondrucker, Plain Text für A4) mit konfigurierbarer Breite und Vorlagen.

## Rollen & Test-Logins

Im Demo sind feste Logins hinterlegt (Passwort jeweils 1234):

- Kellner: `kellner@tsv`
- Küche: `kueche@tsv`
- Bar: `bar@tsv`
- Admin: `admin@tsv`

Nach Login wird abhängig von der Rolle auf die jeweilige Route geleitet.

## Aktuelle Funktionen

- Firebase Auth (E-Mail/Passwort) und User-Profil inkl. Rolle (server/kitchen/bar/admin)
- go_router mit Guards (u. a. /cashier nur für Admin)
- Tischplan aus Firestore (stabile IDs), Badges für Küche/Bar bereit
- Tickets/Bestellungen in Firestore, deterministische Wiederverwendung offener Tickets pro Tisch
- Küche/Bar-Ansichten: Offene Positionen nach Route, „Fertig“-Workflow
- Kasse: Tagesübersicht mit Bar/Karte, Kassenstart (pro Tag), Einlagen/Entnahmen, Artikelaggregation
- Druck: 
	- ESC/POS (Bondrucker, 58/80mm, Spaltenbreite 32/48) 
	- Plain Text (A4-Drucker) mit Vorlagen-Editor (Header/Item/Footer/Bewirtung)
	- Testdruck je Drucker, IP/Port/Modus/Breite konfigurierbar
- Tagesabschlussdruck: Summen (gesamt/bar/karte), Kassenstart/Kasseninhalt, Verkäufe je Artikel

## Projektstruktur (Auszug)

- `lib/app.dart` – GoRouter + Theme
- `lib/main.dart` – Provider-Setup, Notifications
- `lib/models/entities.dart` – Entities & Enums
- `lib/state/*` – Provider (Auth, Tables, Menu, Tickets)
- `lib/screens/*` – UI-Screens (Login, Tischplan, Bestellung, Küche, Bar, Kasse)
 - `lib/util/receipt_service.dart` – Drucklogik (ESC/POS, Plain, Vorlagen, Tagesabschluss)
 - `firestore.rules` – Firestore Security Rules (rollenbasiert)

## Entwickeln & Starten

1) Dependencies holen
2) App starten (Android empfohlen)
3) Optional: Analyzer laufen lassen (VS Code Task „Flutter analyze“)

### Monitoring & Backups

- Crashlytics und Performance sind initialisiert; Fehler und Traces werden (auf Android/iOS) gesammelt.
- Optional: Crashlytics Gradle-Plugin hinzufügen, damit Mapping-Dateien hochgeladen werden (siehe `docs/release-android.md`).
- Cloud Functions: Täglicher Firestore-Export nach GCS um 03:00 Europe/Berlin. Voraussetzung: Umgebungsvariable `EXPORT_BUCKET` setzen und Functions deployen.

Weitere Details in `docs/e2e-checklist.md` und `docs/release-android.md`.

### Drucker einrichten

- Admin → Drucker: Bondrucker (ESC/POS) und Kassendrucker (Plain/ESC-POS) konfigurieren
- Testdruck ausführen, bei Bedarf Breite (32/48) und Modus anpassen
- Vorlagen-Editor für Plain-Text (A4) unter Admin → Druck-Vorlagen

### Tagesabschluss drucken

- Admin → Kasse: Tag wählen (yyyy-MM-dd), Kassenstart setzen (persistiert pro Tag)
- Drucksymbol in der AppBar → Bestätigen → Tagesabschluss wird auf Kassendrucker ausgegeben
 - Einlagen/Entnahmen werden berücksichtigt und gedruckt

### Firestore Security Rules

- Regeln liegen in `firestore.rules` (rollenbasiert: admin/server/kitchen/bar)
- Deployment mit Firebase CLI:

```powershell
firebase deploy --only firestore:rules
```

Oder lokal mit Emulator testen:

```powershell
firebase emulators:start --only firestore
```

### CSV-Export

- In der Kasse (⋮) → “Export CSV (Zwischenablage)”
- Enthält zuerst einen SUMMARY-Block (Tag, Kassenstart, Einlagen, Entnahmen, Bar/Karte/Gesamt, Kasseninhalt)
- Danach detailierte Zeilen mit Belegen/Positionen

## Nächste Schritte (Backlog)

## Datenschutz

- Datenschutzerklärung der App: siehe `docs/privacy-policy.md` (für Play Console unter einer öffentlich erreichbaren URL bereitstellen, z. B. GitHub Pages)
