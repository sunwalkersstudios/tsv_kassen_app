# Datenschutzerklärung für die TSV KassenApp

Stand: 23.10.2025

Diese Datenschutzerklärung informiert Sie über Art, Umfang und Zwecke der Verarbeitung personenbezogener Daten bei Nutzung der TSV KassenApp (nachfolgend „App“).

Verantwortlicher (Betreiber der App)
- Name/Firma: Marcel Weh, Sunwalkers Studios
- Anschrift: Großer Winkel 17E, 31552 Apelern, Deutschland
- E‑Mail: realsunwalkers@gmail.com

## 1. Verarbeitete Datenkategorien

Wir verarbeiten – je nach Rolle und Nutzung – insbesondere folgende Daten:
- Kontodaten: E‑Mail-Adresse und Benutzerkennung (Firebase Auth)
- Rollen/Profil: Rolle (Kellner/Küche/Bar/Admin), Anzeigename
- Bestell- und Kassendaten: Tische, Tickets/Bestellungen, Positionen, Zahlart (Bar/Karte), Umsätze, Tagesabschlüsse
- Benachrichtigungen: Geräte‑Token für Push (FCM)
- App‑Stabilität/Performance: Crash- und Leistungsdaten (Crashlytics/Performance)
- Geräteeinstellungen: lokale App‑Einstellungen (z. B. Kassenstart, Einlagen/Entnahmen, Drucker-IP) in SharedPreferences (nur lokal auf dem Gerät)
- Netzwerk- und Druckdaten: Druckaufträge (Plain/ESC/POS) über lokales Netzwerk an konfigurierte Drucker

## 2. Zwecke der Verarbeitung
- Bereitstellung der App-Funktionen (Tisch-/Bestellverwaltung, Kasse, Druck)
- Nutzerverwaltung und Zugriffssteuerung (Rollen)
- Versand von Push-Benachrichtigungen (z. B. „Ticket fertig“) an berechtigte Nutzergeräte
- Stabilität, Fehleranalyse und Leistungsüberwachung der App
- Datensicherung (Backups) und Wiederherstellung im Fehlerfall

## 3. Rechtsgrundlagen
- Art. 6 Abs. 1 lit. b DSGVO (Vertrag/vertragsähnliches Verhältnis): für die Bereitstellung der bestellten/vereinbarten Funktionen (Kassen- und Bestellprozesse)
- Art. 6 Abs. 1 lit. f DSGVO (berechtigtes Interesse): Stabilität und Sicherheit (Crashlytics/Performance), betriebliche Backups, Missbrauchsverhinderung, interne Auswertungen (z. B. Tagesabschluss)
- Art. 6 Abs. 1 lit. a DSGVO (Einwilligung): soweit Sie Benachrichtigungen aktiv erlauben (System-Prompt)

## 4. Eingesetzte Dienste/Empfänger
- Firebase Authentication (Google Ireland Limited): Authentifizierung per E‑Mail/Passwort
- Cloud Firestore (Google Ireland Limited): Speicherung von Tischen, Tickets/Bestellungen, Verkäufen, Rollen
- Firebase Cloud Messaging (FCM): Zustellung von Push-Benachrichtigungen an Geräte‑Tokens
- Firebase Crashlytics & Performance Monitoring: Fehler- und Leistungsdaten
- Google Cloud Functions und Cloud Storage: serverseitige Funktionen (EU‑Region `europe-west3`) und automatisierte Firestore‑Backups in ein GCS‑Bucket

Eine aktuelle Übersicht der Subdienstleister finden Sie in den Google/Firebase‑Datenschutzhinweisen.

## 5. Datenübermittlung in Drittländer
Firebase kann Daten außerhalb der EU/EWR verarbeiten. Wir konfigurieren Dienste (z. B. Cloud Functions) nach Möglichkeit in EU‑Regionen (z. B. `europe-west3`). Sofern Daten in Drittländer übertragen werden, erfolgt dies auf Basis geeigneter Garantien (z. B. EU‑Standardvertragsklauseln). Details: Datenschutzhinweise von Google/Firebase.

## 6. Speicherdauer
- Konten-/Profildaten: bis zur Löschung des Nutzerkontos oder Widerruf/Beendigung
- Bestell-/Kassendaten: nach betrieblicher/gesetzlicher Erforderlichkeit (z. B. steuerrechtliche Aufbewahrungspflichten); Tagesabschlüsse dienen der Kassenführung
- Geräte‑Tokens: bis zur Erneuerung oder Widerruf/Abmeldung; ungültige Tokens werden regelmäßig bereinigt
- Crash- und Leistungsdaten: gemäß Standardfristen von Firebase/Google
- Lokale Einstellungen (SharedPreferences): bis App‑Deinstallation oder manuell durch Nutzer zurückgesetzt
- Backups: gemäß interner Backup‑Policy; automatisierte Exporte in GCS werden nach angemessenen Fristen gelöscht/rotiert

## 7. Pflichtangaben/Bereitstellung
Die Nutzung der App erfordert in der Regel ein Konto (E‑Mail/Passwort) und eine Rollen‑Zuteilung. Ohne diese Daten ist ein Betrieb nicht möglich. Push‑Benachrichtigungen sind optional (Einwilligung im Systemdialog).

## 8. Berechtigungen der App
- Netzwerkzugriff (Kommunikation mit Firebase, Druckern im lokalen Netzwerk)
- Benachrichtigungen (optional, nur bei Einwilligung)
- Biometrie/Entsperren (optional, zur schnellen Reaktivierung der App)

## 9. Ihre Rechte
Sie haben – im Rahmen der gesetzlichen Voraussetzungen – folgende Rechte:
- Auskunft über die gespeicherten personenbezogenen Daten
- Berichtigung unrichtiger Daten
- Löschung („Recht auf Vergessenwerden“) bzw. Einschränkung der Verarbeitung
- Widerspruch gegen Verarbeitungen auf Basis berechtigter Interessen
- Datenübertragbarkeit
- Widerruf erteilter Einwilligungen mit Wirkung für die Zukunft

Bitte richten Sie Ihre Anfragen an den oben genannten Verantwortlichen. Wir behalten uns vor, bei Zweifeln einen Identitätsnachweis zu verlangen.

## 10. Sicherheit
Wir verwenden Firebase‑Dienste mit rollenbasierten Firestore‑Sicherheitsregeln. Die App kommuniziert verschlüsselt (TLS) mit Firebase. Lokale Netzwerk‑Drucke erfolgen innerhalb Ihres Netzwerks; sorgen Sie für sichere Drucker‑Konfiguration (z. B. geschütztes WLAN, statische IPs, Firewall).

## 11. Kinder/Jugendliche
Die App richtet sich an betriebliche Nutzer (Vereinsheim/Gastronomie) und nicht an Kinder.

## 12. Änderungen dieser Erklärung
Wir können diese Datenschutzerklärung anpassen, wenn sich Dienste, Rechtslage oder Betriebsabläufe ändern. Es gilt die jeweils aktuelle Fassung in der App/unter dem verlinkten Dokument.

---

Hinweis: Diese Vorlage ersetzt keine Rechtsberatung. Bitte prüfen Sie, ob besondere nationale Vorgaben (z. B. Impressumspflicht, steuerrechtliche Anforderungen, Auftragsverarbeitungsvertrag mit Google) für Ihren Anwendungsfall zu ergänzen sind.
