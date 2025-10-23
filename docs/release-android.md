# Android Release Leitfaden

Dieser Leitfaden beschreibt die Schritte für einen stabilen Android-Release.

## 1) Versionierung
- `pubspec.yaml`: `version: <major>.<minor>.<patch>+<build>` anheben

## 2) Keystore & Signierung
- Keystore erstellen oder vorhandenen verwenden
- In `android/app` eine `key.properties` anlegen (nicht einchecken)
```
storePassword=****
keyPassword=****
keyAlias=upload
storeFile=..\\keystore.jks
```
- In `android/app/build.gradle.kts` eine `release`-SigningConfig referenzieren (TODO: Projekt-spezifisch ergänzen)

## 3) Firebase
- `google-services.json` (Android) aktuell in `android/app` hinterlegen
- Crashlytics/Performance sind in der App initialisiert
  - Optional (empfohlen): Crashlytics Gradle Plugin hinzufügen, damit Mapping-Dateien hochgeladen werden
    - In `android/settings.gradle.kts`:
      ```kotlin
      plugins {
          id("com.google.firebase.crashlytics") version "3.0.2" apply false
      }
      ```
    - In `android/app/build.gradle.kts`:
      ```kotlin
      plugins {
          id("com.google.firebase.crashlytics")
      }
      ```

## 4) Build
- Gerät/Emulator trennen, um echte Release-Builds zu erzeugen
- In VS Code/Terminal Release bauen:
  - `flutter build apk --release`
  - oder `flutter build appbundle --release`

## 5) Testen
- Auf mindestens einem echten Gerät installieren
- E2E-Checkliste (docs/e2e-checklist.md) durchgehen

## 6) Play Console
- App Bundle (.aab) hochladen
- Inhalte (Berechtigungen, Datenschutzerklärung, Screenshots) pflegen
- Rollout schrittweise (z. B. Interner Test → Geschlossener Test → Produktion)

## 7) Troubleshooting
- Crashlytics-Symbolik fehlt: Gradle-Plugin für Crashlytics prüfen, ProGuard/R8 Mapping Upload
- Netzwerk/Printing: Firewall und statische IPs prüfen
- FCM: Gerätetoken prüfen, App-Benachrichtigungen erlaubt?
