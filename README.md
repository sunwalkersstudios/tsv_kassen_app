# TSV Kassen App

Eine einfache Web-Anwendung für die TSV Kassen mit integrierter Datenschutzerklärung.

## Struktur

- `index.html` - Hauptseite der Anwendung
- `datenschutz.html` - Datenschutzerklärungsseite
- `styles.css` - Stylesheet für das Design

## Datenschutzerklärung bearbeiten

### So fügen Sie Ihren eigenen Datenschutztext ein:

1. Öffnen Sie die Datei `datenschutz.html`
2. Suchen Sie nach dem Kommentar `HIER KÖNNEN SIE IHREN DATENSCHUTZTEXT EINFÜGEN`
3. Zwischen diesem Kommentar und dem Kommentar `ENDE DES BEREICHS FÜR IHREN TEXT` können Sie Ihren Text einfügen

### HTML-Formatierung:

- **Absätze**: Verwenden Sie `<p>Ihr Text hier</p>` für normale Absätze
- **Überschriften**: 
  - `<h3>Hauptüberschrift</h3>` für Hauptabschnitte
  - `<h4>Unterüberschrift</h4>` für Unterabschnitte
- **Listen**: 
  ```html
  <ul>
      <li>Listenpunkt 1</li>
      <li>Listenpunkt 2</li>
  </ul>
  ```
- **Fettgedruckter Text**: `<strong>Wichtiger Text</strong>`
- **Zeilenumbruch**: `<br>`

### Beispiel:

```html
<h3>Meine Überschrift</h3>
<p>Dies ist ein Absatz mit normalem Text.</p>
<p><strong>Dies ist wichtiger Text</strong> in einem weiteren Absatz.</p>

<h4>Eine Unterüberschrift</h4>
<ul>
    <li>Erster Punkt</li>
    <li>Zweiter Punkt</li>
</ul>
```

### Wichtige Platzhalter zum Ersetzen:

In der `datenschutz.html` finden Sie mehrere Platzhalter in eckigen Klammern `[...]`, die Sie durch Ihre eigenen Informationen ersetzen sollten:

- `[HIER KÖNNEN SIE IHREN HOSTING-ANBIETER EINTRAGEN]`
- `[HIER KÖNNEN SIE IHRE KONTAKTDATEN EINTRAGEN]`
- `[TELEFONNUMMER]`
- `[E-MAIL-ADRESSE]`

## Die App verwenden

1. Öffnen Sie `index.html` in Ihrem Webbrowser
2. Navigieren Sie über das Menü zur Datenschutzerklärung
3. Die Seiten können auf jedem Webserver gehostet werden

## Anpassungen

- **Farben ändern**: Bearbeiten Sie die Farben in `styles.css` (Suchen Sie nach `#007bff` für die Hauptfarbe)
- **Navigation erweitern**: Fügen Sie weitere Links in der `<nav>` Sektion in beiden HTML-Dateien hinzu
- **Layout anpassen**: Bearbeiten Sie die CSS-Datei nach Ihren Wünschen
