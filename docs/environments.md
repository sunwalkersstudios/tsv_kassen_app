# Umgebungen (Staging/Prod)

Empfehlung: Zwei Firebase-Projekte (z. B. `tsv-kasse-staging` und `tsv-kasse-prod`) und Flutter-Flavors verwenden.

## Setup mit FlutterFire
1) Für jedes Projekt FlutterFire konfigurieren:
   - `flutterfire configure --project=<staging-project> --out=lib/firebase_options_staging.dart`
   - `flutterfire configure --project=<prod-project> --out=lib/firebase_options_prod.dart`
2) Pro Plattform die Konfigs ablegen:
   - Android: `android/app/google-services.json` (staging/prod Varianten per Flavor)
   - iOS: `ios/Runner/GoogleService-Info.plist` (staging/prod Varianten per Scheme)

## Flavors anlegen
- Android Gradle (productFlavors `staging`/`prod`) und unterschiedliche `applicationId`
- iOS Schemes/Configurations für `staging`/`prod`

## Umschalten zur Laufzeit
- Einen einfachen Env-Switch bauen:
  - per `--dart-define=FLAVOR=staging` und eine Factory nutzen, die die passenden `DefaultFirebaseOptions.currentPlatform` liefert
  - oder über unterschiedliche `main_staging.dart`/`main_prod.dart`

## Hinweise
- Genaue Flavor-Konfiguration hängt vom Projekt ab; startweise reichen zwei `main_*.dart` Dateien und Copy der jeweiligen Service-Dateien.
- Cloud Functions & Regeln getrennt pro Projekt deployen.
