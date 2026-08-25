// Rendert die Entwurfsbildschirme als PNG.
//
// Kein Test im eigentlichen Sinn, sondern ein Bildgenerator: Flutter zeichnet
// die Widgets kopflos und legt die Bilder unter test/design/bilder/ ab. So
// laesst sich die Gestaltung ansehen, ohne die App auf ein Geraet zu bringen -
// und was hier zu sehen ist, ist echtes Flutter-Rendering mit dem echten
// Schema, kein nachgebautes Mockup.
//
// Aufruf:
//   flutter test test/design/render.dart --update-goldens
//
// Die Datei heisst bewusst nicht *_test.dart und wird deshalb vom normalen
// "flutter test" nicht mit aufgesammelt: Sie erzeugt Bilder, sie prueft nichts.
// Liefe sie mit, waere die Testsuite nach jeder gewollten Gestaltungsaenderung
// rot - und auf einem frischen Klon ohnehin, weil die Bilder nicht versioniert
// sind.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:tsv/theme.dart';
import 'mock_screens.dart';

/// Tablet im Querformat - so wird die App benutzt.
const _tablet = Size(1280, 800);

/// Ohne echte Schrift zeichnet die Testumgebung Text als schwarze Kaesten.
/// Roboto liegt im Flutter-SDK und wird hier zur Laufzeit nachgeladen.
Future<void> _ladeSchrift() async {
  // Vom laufenden Dart-Programm aus nach oben wandern, bis der Schriftordner
  // des SDK auftaucht. Die Verschachtelungstiefe unterscheidet sich je nach
  // Plattform und Flutter-Version, deshalb suchen statt zaehlen.
  Directory? ordner;
  var d = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8 && ordner == null; i++) {
    final kandidat = Directory('${d.path}/artifacts/material_fonts');
    if (kandidat.existsSync()) ordner = kandidat;
    if (d.parent.path == d.path) break;
    d = d.parent;
  }
  if (ordner == null) {
    // ignore: avoid_print
    print('WARNUNG: Schriftordner nicht gefunden - Text wird als Kaesten gezeichnet.');
    return;
  }
  // ignore: avoid_print
  print('Schriften aus: ${ordner.path}');

  // Ein FontLoader je Schnitt: mehrere Dateien unter einem Namen wuerden
  // sonst als eine Familie ohne Gewichtsunterschiede zusammenfallen.
  Future<void> lade(String datei, FontWeight _) async {
    final f = File('${ordner!.path}/$datei');
    if (!f.existsSync()) return;
    final lader = FontLoader('Roboto')
      ..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
    await lader.load();
  }

  // Reihenfolge zaehlt: der zuerst geladene Schnitt gilt als Standard.
  await lade('roboto-regular.ttf', FontWeight.w400);
  await lade('roboto-medium.ttf', FontWeight.w500);
  await lade('roboto-bold.ttf', FontWeight.w700);
  await lade('roboto-black.ttf', FontWeight.w900);

  // Ohne diese Schrift zeichnet Flutter jedes Symbol als leeres Kaestchen.
  final icons = File('${ordner.path}/materialicons-regular.otf');
  if (icons.existsSync()) {
    final lader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)));
    await lader.load();
  }
}

void main() {
  setUpAll(() async {
    await _ladeSchrift();
    // Die Kasse formatiert Datumsangaben auf Deutsch; ohne geladene
    // Datumssymbole wirft jedes DateFormat mit Locale 'de_DE'.
    await initializeDateFormatting('de_DE', null);
  });

  Future<void> zeichne(
    WidgetTester tester,
    String name,
    Widget bildschirm,
    Brightness helligkeit,
  ) async {
    tester.view
      ..physicalSize = _tablet
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.preview(helligkeit, 'Roboto'),
      home: bildschirm,
    ));
    await tester.pumpAndSettle();

    final suffix = helligkeit == Brightness.light ? 'hell' : 'dunkel';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('bilder/$name-$suffix.png'),
    );
  }

  testWidgets('Tischplan hell', (t) => zeichne(t, 'tischplan', const MockTablePlan(), Brightness.light));
  testWidgets('Tischplan dunkel', (t) => zeichne(t, 'tischplan', const MockTablePlan(), Brightness.dark));
  testWidgets('Bestellung hell', (t) => zeichne(t, 'bestellung', const MockOrder(), Brightness.light));
  testWidgets('Bestellung dunkel', (t) => zeichne(t, 'bestellung', const MockOrder(), Brightness.dark));
  testWidgets('Küche hell', (t) => zeichne(t, 'kueche', const MockKitchen(), Brightness.light));
  testWidgets('Küche dunkel', (t) => zeichne(t, 'kueche', const MockKitchen(), Brightness.dark));
  testWidgets('Kasse hell', (t) => zeichne(t, 'kasse', const MockCashier(), Brightness.light));
  testWidgets('Kasse dunkel', (t) => zeichne(t, 'kasse', const MockCashier(), Brightness.dark));
}
