"""
Erzeugt saemtliche App-Icons aus dem Vereinslogo.

Das Logo liegt als grosse PNG-Datei vor: blaue Zeichnung auf weissem Grund,
ausserhalb des Wappens durchsichtig. Fuer das Icon wird daraus eine einfarbige
Marke - das Weiss verschwindet, das Blau wird zur Hausfarbe der App.

Weshalb gerechnet und nicht von Hand freigestellt: Das Wappen hat weiche
Kanten. Ein harter Schwellwert wuerde daraus Treppen machen. Stattdessen gilt
der Blauanteil eines Pixels als seine Deckkraft, womit die Kanten erhalten
bleiben.

    python tool/icons.py                  # Kupfer auf Espresso (Vorgabe)
    python tool/icons.py --hell           # Papier auf Kupfer
    python tool/icons.py --vorschau x.png # nur Musterbild, nichts ueberschreiben

Danach neu bauen - Icons stecken in den Ressourcen, ein Hot Reload genuegt
nicht.
"""
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFont

WURZEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
QUELLE = os.path.join(WURZEL, 'assets', 'TSV-Logo.png')
RES = os.path.join(WURZEL, 'android', 'app', 'src', 'main', 'res')

# Hausfarben aus lib/theme.dart - hier gespiegelt, damit das Icon nicht
# auseinanderlaeuft, wenn dort etwas geaendert wird.
KUPFER = (201, 118, 45)      # AppColors.copper
ESPRESSO = (23, 19, 14)      # warmes Schwarz, Grund des dunklen Themas
PAPIER = (250, 246, 240)     # warmes Papierweiss

MASTER = 2048                # Zwischengroesse, aus der alles verkleinert wird

# Anteil der Kantenlaenge, den das Wappen einnimmt.
#
# Ein adaptives Icon ist 108 Einheiten breit, sichtbar bleibt je nach Geraet
# nur ein Kreis von etwa 72. Bei 70 sitzt das Wappen knapp innerhalb - gross
# genug, dass es nicht verloren wirkt, klein genug, dass keine Launcher-Maske
# hineinschneidet.
ANTEIL_ADAPTIV = 70 / 108
ANTEIL_EINFARBIG = 62 / 108  # Themenicons werden staerker beschnitten
ANTEIL_ALT = 0.76            # alte Icons bringen ihre Form selbst mit

DICHTEN = [('mdpi', 1), ('hdpi', 1.5), ('xhdpi', 2), ('xxhdpi', 3), ('xxxhdpi', 4)]


def marke(farbe, groesse):
    """Das Wappen als einfarbige Marke auf durchsichtigem Grund."""
    im = Image.open(QUELLE).convert('RGBA')

    # Durchsichtigen Rand abschneiden und auf ein Quadrat bringen, damit das
    # Wappen spaeter wirklich mittig sitzt.
    kasten = im.getbbox()
    if kasten:
        im = im.crop(kasten)
    kante = max(im.size)
    quadrat = Image.new('RGBA', (kante, kante), (0, 0, 0, 0))
    quadrat.alpha_composite(im, ((kante - im.width) // 2, (kante - im.height) // 2))
    im = quadrat.resize((groesse, groesse), Image.LANCZOS)

    rot, _gruen, _blau, alpha = im.split()
    # Rotkanal als Mass fuer den Blauanteil: Weiss hat 255, das Vereinsblau 17.
    # Dazwischen liegen die weichen Kanten, die genau so erhalten bleiben.
    anteil = rot.point(lambda v: int(max(0, min(255, (255 - v) * 255 / 238))))

    aus = Image.new('RGBA', im.size, farbe + (255,))
    aus.putalpha(ImageChops.multiply(alpha, anteil))
    return aus


def auf_grund(grund, markenfarbe, rund, groesse, anteil=ANTEIL_ALT):
    """Marke auf einer eigenen Flaeche - fuer alte Icons ohne Launcher-Maske."""
    bild = Image.new('RGBA', (MASTER, MASTER), (0, 0, 0, 0))
    stift = ImageDraw.Draw(bild)
    kasten = [0, 0, MASTER - 1, MASTER - 1]
    if rund:
        stift.ellipse(kasten, fill=grund + (255,))
    else:
        stift.rounded_rectangle(kasten, radius=int(MASTER * 0.22), fill=grund + (255,))

    logo = marke(markenfarbe, int(MASTER * anteil))
    rand = (MASTER - logo.width) // 2
    bild.alpha_composite(logo, (rand, rand))
    return bild.resize((groesse, groesse), Image.LANCZOS)


def freistehend(markenfarbe, groesse, anteil):
    """Marke auf durchsichtigem Grund - fuer adaptive Icons."""
    bild = Image.new('RGBA', (MASTER, MASTER), (0, 0, 0, 0))
    logo = marke(markenfarbe, int(MASTER * anteil))
    rand = (MASTER - logo.width) // 2
    bild.alpha_composite(logo, (rand, rand))
    return bild.resize((groesse, groesse), Image.LANCZOS)


def sichern(bild, *teile):
    pfad = os.path.join(*teile)
    os.makedirs(os.path.dirname(pfad), exist_ok=True)
    bild.save(pfad)
    return pfad


def schreibe_android(grund, markenfarbe):
    geschrieben = []
    for name, faktor in DICHTEN:
        ordner = os.path.join(RES, 'mipmap-' + name)
        geschrieben.append(sichern(
            auf_grund(grund, markenfarbe, False, int(48 * faktor)),
            ordner, 'ic_launcher.png'))
        geschrieben.append(sichern(
            auf_grund(grund, markenfarbe, True, int(48 * faktor)),
            ordner, 'ic_launcher_round.png'))
        geschrieben.append(sichern(
            freistehend(markenfarbe, int(108 * faktor), ANTEIL_ADAPTIV),
            ordner, 'ic_launcher_foreground.png'))
        # Themenicons faerbt das System selbst ein, deshalb weiss.
        geschrieben.append(sichern(
            freistehend((255, 255, 255), int(108 * faktor), ANTEIL_EINFARBIG),
            ordner, 'ic_launcher_monochrome.png'))

    xml = ('<?xml version="1.0" encoding="utf-8"?>\n'
           '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
           '    <background android:drawable="@color/ic_launcher_background" />\n'
           '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
           '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />\n'
           '</adaptive-icon>\n')
    for datei in ('ic_launcher.xml', 'ic_launcher_round.xml'):
        pfad = os.path.join(RES, 'mipmap-anydpi-v26', datei)
        os.makedirs(os.path.dirname(pfad), exist_ok=True)
        with open(pfad, 'w', encoding='utf-8') as f:
            f.write(xml)
        geschrieben.append(pfad)

    farbe = '#%02X%02X%02X' % grund
    pfad = os.path.join(RES, 'values', 'ic_launcher_background.xml')
    os.makedirs(os.path.dirname(pfad), exist_ok=True)
    with open(pfad, 'w', encoding='utf-8') as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
                '    <color name="ic_launcher_background">%s</color>\n</resources>\n' % farbe)
    geschrieben.append(pfad)
    return geschrieben


def schreibe_ios(grund, markenfarbe):
    """iOS erlaubt keine Durchsichtigkeit im App-Icon, deshalb flach gerechnet."""
    ordner = os.path.join(WURZEL, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
    if not os.path.isdir(ordner):
        return []
    geschrieben = []
    for datei in sorted(os.listdir(ordner)):
        if not datei.endswith('.png'):
            continue
        kante = Image.open(os.path.join(ordner, datei)).size[0]
        # Volle Flaeche ohne eigene Ecken - die Rundung macht iOS selbst.
        bild = Image.new('RGB', (MASTER, MASTER), grund)
        logo = marke(markenfarbe, int(MASTER * 0.72))
        rand = (MASTER - logo.width) // 2
        bild.paste(logo, (rand, rand), logo)
        geschrieben.append(sichern(bild.resize((kante, kante), Image.LANCZOS), ordner, datei))
    return geschrieben


def schreibe_web(grund, markenfarbe):
    web = os.path.join(WURZEL, 'web')
    if not os.path.isdir(web):
        return []
    geschrieben = [sichern(auf_grund(grund, markenfarbe, False, 32), web, 'favicon.png')]
    for kante in (192, 512):
        geschrieben.append(sichern(
            auf_grund(grund, markenfarbe, False, kante),
            web, 'icons', 'Icon-%d.png' % kante))
        # Maskierbare Icons brauchen mehr Luft, das System schneidet zu.
        bild = Image.new('RGBA', (MASTER, MASTER), grund + (255,))
        logo = marke(markenfarbe, int(MASTER * 0.6))
        rand = (MASTER - logo.width) // 2
        bild.alpha_composite(logo, (rand, rand))
        geschrieben.append(sichern(bild.resize((kante, kante), Image.LANCZOS),
                                   web, 'icons', 'Icon-maskable-%d.png' % kante))
    return geschrieben


def schrift(groesse):
    for name in ('segoeui.ttf', 'arial.ttf'):
        pfad = os.path.join('C:', os.sep, 'Windows', 'Fonts', name)
        if os.path.exists(pfad):
            return ImageFont.truetype(pfad, groesse)
    return ImageFont.load_default()


def vorschau(ziel):
    """Musterbild mit beiden Fassungen in echten Anzeigegroessen."""
    breite, hoehe = 1240, 760
    blatt = Image.new('RGB', (breite, hoehe), (233, 227, 218))
    stift = ImageDraw.Draw(blatt)
    kopf, klein = schrift(30), schrift(19)

    stift.text((60, 46), 'TSV Sportheim - App-Icon', font=kopf, fill=(36, 29, 21))
    stift.text((60, 86), 'Vereinswappen in den Farben der App', font=klein, fill=(120, 105, 90))

    fassungen = [
        ('Kupfer auf Espresso', ESPRESSO, KUPFER),
        ('Papier auf Kupfer', KUPFER, PAPIER),
    ]
    for i, (titel, grund, mark) in enumerate(fassungen):
        x = 60 + i * 600
        y = 150
        gross = auf_grund(grund, mark, False, 240)
        blatt.paste(gross, (x, y), gross)
        rund = auf_grund(grund, mark, True, 240)
        blatt.paste(rund, (x + 275, y), rund)
        stift.text((x, y + 266), titel, font=kopf, fill=(36, 29, 21))

        # Echte Anzeigegroessen zum Gegenpruefen: mdpi bis xxhdpi.
        zx = x
        for kante in (48, 72, 96, 144):
            ic = auf_grund(grund, mark, True, kante)
            blatt.paste(ic, (zx, y + 330 + (144 - kante) // 2), ic)
            zx += kante + 26
        stift.text((x, y + 500), '48 - 72 - 96 - 144 px: so klein zeigt es kein',
                   font=klein, fill=(120, 105, 90))
        stift.text((x, y + 524), 'aktuelles Geraet, nur zur Gegenprobe.',
                   font=klein, fill=(120, 105, 90))

    blatt.save(ziel)
    return ziel


if __name__ == '__main__':
    hell = '--hell' in sys.argv
    grund, markenfarbe = (KUPFER, PAPIER) if hell else (ESPRESSO, KUPFER)

    if '--vorschau' in sys.argv:
        stelle = sys.argv.index('--vorschau') + 1
        ziel = sys.argv[stelle] if len(sys.argv) > stelle else 'icon-vorschau.png'
        print('Musterbild: ' + vorschau(ziel))
        raise SystemExit(0)

    dateien = schreibe_android(grund, markenfarbe)
    dateien += schreibe_ios(grund, markenfarbe)
    dateien += schreibe_web(grund, markenfarbe)
    print('%d Dateien geschrieben (%s auf %s)'
          % (len(dateien), 'Papier' if hell else 'Kupfer', 'Kupfer' if hell else 'Espresso'))
