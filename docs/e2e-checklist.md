# E2E Test-Checkliste (Gaststätte)

Ziel: Vor-Ort die komplette Kassenkette stabil testen. Hake jede Zeile ab.

## Vorbereitung
- [ ] WLAN stabil, Drucker (Bondrucker + A4) im selben Netz, IPs notiert
- [ ] Firebase-Projekt verbunden; Firestore-Regeln deployed (siehe README)
- [ ] Cloud Functions deployed; `EXPORT_BUCKET` gesetzt (Backups)
- [ ] Testgeräte geladen; App in Release/Profiling installiert

## Rollen & Login
- [ ] Login als Kellner, Küche, Bar, Admin funktioniert
- [ ] Role-basiertes Routing korrekt (Kellner→Tische, Küche→Küche, Bar→Bar, Admin→Admin)
- [ ] Admin-Guard schützt /admin und /cashier

## Tischplan & Tickets
- [ ] Nur aktive Tische sichtbar; Leere-Status korrekt
- [ ] Ticket-Wiederverwendung (offene Bestellungen pro Tisch) stabil
- [ ] Statuswechsel Küche/Bar auf „fertig“ korrekt und nur für eigene Route möglich

## Drucken
- [ ] ESC/POS: Testdruck auf Bondrucker, Breite (32/48) korrekt
- [ ] A4/Plain: Testdruck, Vorlage passt (Header/Items/Footer)
- [ ] Zahlungsbelegdruck nach Verkauf funktioniert

## Kasse / Tagesabschluss
- [ ] Tagesdatum wählbar; Kassenstart setzt und persistiert
- [ ] Einlagen und Entnahmen werden erfasst und in Summen berücksichtigt
- [ ] CSV-Export enthält SUMMARY + Detailzeilen; Zwischenablage pastebar
- [ ] Tagesabschlussdruck: Summen bar/karte/gesamt, Kassenstart & Kasseninhalt, je-Artikel sortiert, Unterschriftszeilen
- [ ] „Tag zurücksetzen“ leert Kassenstart/Einlagen/Entnahmen

## Push & Monitoring
- [ ] FCM-Push: Ticket fertig → Benachrichtigung am Kellnergerät
- [ ] Crashlytics: Testfehler provozieren (optional) → in Console sichtbar
- [ ] Performance: Startup-Trace/Screen-Traces sichtbar (optional)

## Backups & Sicherheit
- [ ] Geplanter Firestore-Export in GCS läuft (nächster Tag prüfen)
- [ ] Security Rules: Änderungen/Deletes wie erwartet blockiert (Sales append-only)

## Notizen
- [ ] Auffälligkeiten/Verbesserungen dokumentieren
