# Schlüssel und Secrets sicher verwalten

Kurzanleitung, wie du API‑Keys, Keystores und Konfigurationsdateien sicher handhabst und was bei einem Leak zu tun ist.

## TL;DR

- Diese Dateien niemals ins Git‑Repository committen:
  - `android/app/google-services.json`
  - `android/app/key.properties`
  - `android/keystore.jks`
- API‑Key im Google Cloud Projekt einschränken: nur Android‑App `de.tsv.kassenapp` + SHA‑1 (Upload & Play App Signing).
- Bei Leak: Schlüssel rotieren und Historie bereinigen (siehe unten).

## Dateien aus Git fernhalten

Die `.gitignore` enthält bereits Regeln für die oben genannten Dateien. Falls eine dieser Dateien dennoch einmal committed wurde, genügt ein `.gitignore` nicht – dann ist eine History‑Bereinigung erforderlich (siehe „Historie bereinigen“).

## API‑Key einschränken (Google Cloud Console)

1. Öffne das Projekt:  
   https://console.cloud.google.com/apis/credentials?project=tsv_kassen_app
2. Wähle deinen API‑Key (der in `google-services.json` steht).
3. Setze „Application restrictions“ auf „Android apps“ und füge hinzu:
   - Package name: `de.tsv.kassenapp`
   - SHA‑1 Fingerprints: Upload‑Schlüssel und Play App Signing‑Schlüssel
4. Optional: „API restrictions“ nur setzen, wenn exakt bekannt ist, welche APIs verwendet werden. Für Firebase‑Schlüssel genügen i. d. R. die App‑Beschränkungen.

SHA‑1 finden:

- Upload‑Schlüssel (lokaler Keystore):
  - `keytool -list -v -keystore android/keystore.jks -alias upload`
- Play App Signing‑Schlüssel:
  - Play Console → App → Einrichtung → App‑Integrität → „App‑Signierschlüssel“

## API‑Key rotieren (optional, z. B. nach Leak)

1. In der Cloud Console auf dem API‑Key „Regenerate key“ (oder neuen erstellen).
2. Beschränkungen wie oben setzen (Android + SHA‑1).
3. In der Firebase Console → Projekteinstellungen → Android‑App die neue `google-services.json` herunterladen.
4. Lokal nach `android/app/google-services.json` legen (Datei ist git‑ignored).
5. App neu bauen und testen.

## Play App Signing und Upload‑Key

Aktiviere Play App Signing, damit Google deinen endgültigen App‑Signierschlüssel verwaltet. Dein lokaler Keystore signiert nur den Upload. Bei Leak des Upload‑Keys:

1. In der Play Console → App → Einrichtung → App‑Integrität → Upload‑Schlüssel zurücksetzen.
2. Neuen Keystore lokal erstellen und das Upload‑Zertifikat (PEM) in der Play Console hinterlegen.
3. `android/app/key.properties` auf den neuen Keystore aktualisieren (Datei bleibt lokal, nicht committen).

## Historie bereinigen (bereits ausgeführt)

In diesem Repo wurde die Datei `android/app/google-services.json` aus der Git‑Historie entfernt, damit sie nicht mehr abrufbar ist. Vorgehen (Dokumentation):

1. Backup‑Tag erstellen (lokal):
   - `git tag backup/pre-filter-YYYY-MM-DD`
2. Tool installieren (eine Option):
   - `py -3 -m pip install --user git-filter-repo`
3. Historie neu schreiben und die Datei entfernen:
   - `py -3 -m git_filter_repo --force --invert-paths --path android/app/google-services.json`
4. Remote neu setzen und Force‑Push auf main:
   - `git remote add origin <YOUR_REMOTE_URL>` (falls entfernt)
   - `git push -u origin main --force`

Hinweis: Backups/Tags, die vor dem Cleanup gepusht wurden, können die Datei weiterhin enthalten. Entferne oder erneuere solche Referenzen, wenn nötig.

## Lokale Entwicklung

- Halte `google-services.json` nur lokal im Projekt (Git ignoriert diese Datei ohnehin).
- Nutze `key.properties` und `keystore.jks` nur lokal; sichere die Dateien getrennt (Passwort‑Manager/Secrets‑Storage).
- Für Team‑Setups: teile nur die für Upload nötigen Zertifikate (public), niemals den privaten Keystore.
