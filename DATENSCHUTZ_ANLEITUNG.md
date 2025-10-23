# Anleitung: Datenschutzerklärung bearbeiten

## Wo füge ich meinen Datenschutztext ein?

Öffnen Sie die Datei **`datenschutz.html`** in einem Texteditor.

## Wo genau ist der Bereich zum Einfügen?

Suchen Sie nach diesem Kommentar in der Datei:

```html
<!-- 
========================================
HIER KÖNNEN SIE IHREN DATENSCHUTZTEXT EINFÜGEN
========================================
```

**Direkt nach diesem Kommentar** können Sie Ihren eigenen Text einfügen oder den vorhandenen Beispieltext anpassen.

Der bearbeitbare Bereich endet bei diesem Kommentar:

```html
<!-- 
========================================
ENDE DES BEREICHS FÜR IHREN TEXT
========================================
-->
```

## Wie formatiere ich meinen Text?

### Einfache HTML-Tags:

1. **Normaler Text in Absätzen:**
   ```html
   <p>Dies ist ein normaler Absatz.</p>
   ```

2. **Überschriften:**
   ```html
   <h3>Große Überschrift</h3>
   <h4>Kleinere Überschrift</h4>
   ```

3. **Fettgedruckter Text:**
   ```html
   <p><strong>Dieser Text ist fett</strong> und dieser nicht.</p>
   ```

4. **Aufzählungen:**
   ```html
   <ul>
       <li>Erster Punkt</li>
       <li>Zweiter Punkt</li>
       <li>Dritter Punkt</li>
   </ul>
   ```

5. **Zeilenumbruch:**
   ```html
   Erste Zeile<br>
   Zweite Zeile
   ```

## Vollständiges Beispiel:

```html
<h3>1. Datenschutz auf einen Blick</h3>

<h4>Allgemeine Hinweise</h4>
<p>Die folgenden Hinweise geben einen einfachen Überblick darüber, was mit Ihren personenbezogenen Daten passiert, wenn Sie diese App nutzen.</p>

<p><strong>Wichtig:</strong> Personenbezogene Daten sind alle Daten, mit denen Sie persönlich identifiziert werden können.</p>

<h3>2. Kontaktdaten</h3>
<p>
Verantwortliche Stelle:<br>
Max Mustermann<br>
Musterstraße 123<br>
12345 Musterstadt<br>
<br>
Telefon: +49 123 456789<br>
E-Mail: datenschutz@beispiel.de
</p>
```

## Wichtige Platzhalter zum Ersetzen:

Die Datei enthält mehrere Platzhalter in eckigen Klammern, die Sie ersetzen sollten:

- `[HIER KÖNNEN SIE IHREN HOSTING-ANBIETER EINTRAGEN]`
- `[HIER KÖNNEN SIE IHRE KONTAKTDATEN EINTRAGEN]`
- `[TELEFONNUMMER]`
- `[E-MAIL-ADRESSE]`

Ersetzen Sie diese durch Ihre echten Informationen.

## Tipp für Einsteiger:

Wenn Sie noch nie mit HTML gearbeitet haben:

1. Kopieren Sie einen vorhandenen Absatz (z.B. `<p>Beispieltext</p>`)
2. Fügen Sie ihn direkt darunter ein
3. Ändern Sie nur den Text zwischen `<p>` und `</p>`
4. Lassen Sie die Tags `<p>` und `</p>` unverändert

Das gleiche gilt für alle anderen Tags!

## Datei speichern und testen:

1. Speichern Sie die `datenschutz.html` Datei
2. Öffnen Sie die Datei in Ihrem Webbrowser (Doppelklick oder Rechtsklick → "Öffnen mit" → Browser)
3. Überprüfen Sie, ob alles richtig angezeigt wird
4. Falls nicht, überprüfen Sie, ob alle öffnenden Tags (`<p>`) auch schließende Tags (`</p>`) haben

## Weitere Hilfe:

Bei Fragen oder Problemen können Sie sich an einen Webentwickler wenden oder in der Datei `README.md` weitere Informationen finden.
