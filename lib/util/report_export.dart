import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/cash_day.dart';
import '../models/report_period.dart';
import '../models/sales_summary.dart';
import 'money.dart';

/// Erzeugt Kassenschnitte als CSV-Datei oder PDF und reicht sie an den
/// Teilen-Dialog des Geraets weiter.
///
/// Loest den frueheren Export ab, der die Daten nur in die Zwischenablage
/// geschrieben hat.
class ReportExport {
  ReportExport._();

  static final _stamp = DateFormat('dd.MM.yyyy HH:mm');

  // ------------------------------------------------------------------ CSV

  /// Baut den CSV-Inhalt. Semikolon als Trenner und Komma als Dezimalzeichen,
  /// damit deutsches Excel die Datei ohne Importdialog oeffnet.
  static String buildCsv({
    required ReportPeriod period,
    required SalesSummary summary,
    required Map<String, CashDay> cashDays,
    required int drawerCents,
  }) {
    String f(int cents) => Money.plain(cents);
    String esc(String v) =>
        RegExp(r'[;"\r\n]').hasMatch(v) ? '"${v.replaceAll('"', '""')}"' : v;

    final b = StringBuffer();
    b.writeln('Kassenschnitt;${esc(period.label)}');
    b.writeln('Zeitraum;${period.fromKey};bis;${period.toKey}');
    b.writeln('Erstellt;${_stamp.format(DateTime.now())}');
    b.writeln();

    b.writeln('ZUSAMMENFASSUNG');
    b.writeln('Belege;${summary.receipts}');
    b.writeln('Bar;${f(summary.cashCents)}');
    b.writeln('Karte;${f(summary.cardCents)}');
    b.writeln('Gesamt;${f(summary.totalCents)}');

    final opening = cashDays.values.fold(0, (a, d) => a + d.openingCents);
    final deposit = cashDays.values.fold(0, (a, d) => a + d.depositCents);
    final withdrawal = cashDays.values.fold(0, (a, d) => a + d.withdrawalCents);
    b.writeln('Kassenstart;${f(opening)}');
    b.writeln('Einlagen;${f(deposit)}');
    b.writeln('Entnahmen;${f(withdrawal)}');
    b.writeln('Kasseninhalt;${f(drawerCents)}');
    b.writeln();

    if (summary.days.length > 1) {
      b.writeln('TAGE');
      b.writeln('Tag;Belege;Bar;Karte;Gesamt');
      for (final d in summary.days) {
        b.writeln('${d.day};${d.receipts};${f(d.cashCents)};${f(d.cardCents)};${f(d.totalCents)}');
      }
      b.writeln();
    }

    b.writeln('ARTIKEL');
    b.writeln('Artikel;Kategorie;Route;Menge;Umsatz');
    for (final i in summary.items) {
      b.writeln('${esc(i.name)};${esc(i.category)};${esc(i.route)};${i.qty};${f(i.totalCents)}');
    }
    return b.toString();
  }

  /// Schreibt den CSV-Inhalt in eine Datei und oeffnet den Teilen-Dialog.
  static Future<void> shareCsv({
    required ReportPeriod period,
    required SalesSummary summary,
    required Map<String, CashDay> cashDays,
    required int drawerCents,
  }) async {
    final csv = buildCsv(
      period: period,
      summary: summary,
      cashDays: cashDays,
      drawerCents: drawerCents,
    );
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Kassenschnitt-${period.fileLabel}.csv');
    // Byte Order Mark voranstellen, sonst zerlegt Excel die Umlaute
    await file.writeAsString('﻿$csv');
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'text/csv')],
      subject: 'Kassenschnitt ${period.label}',
      text: 'Kassenschnitt ${period.label}',
    ));
  }

  // ------------------------------------------------------------------ PDF

  static Future<Uint8List> buildPdf({
    required ReportPeriod period,
    required SalesSummary summary,
    required Map<String, CashDay> cashDays,
    required int drawerCents,
    String orgName = 'TSV KassenApp',
  }) async {
    final doc = pw.Document(title: 'Kassenschnitt ${period.fileLabel}');
    final opening = cashDays.values.fold(0, (a, d) => a + d.openingCents);
    final deposit = cashDays.values.fold(0, (a, d) => a + d.depositCents);
    final withdrawal = cashDays.values.fold(0, (a, d) => a + d.withdrawalCents);

    final accent = PdfColors.green800;
    final head = pw.TextStyle(fontSize: 8, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold);

    pw.Widget kpi(String label, String value, {bool strong = false}) => pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
              color: strong ? PdfColors.grey100 : null,
            ),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(label.toUpperCase(), style: head),
              pw.SizedBox(height: 3),
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal)),
            ]),
          ),
        );

    pw.Widget section(String title) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 18, bottom: 6),
          child: pw.Text(title,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: accent)),
        );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 40, 36, 40),
      header: (ctx) => ctx.pageNumber == 1
          ? pw.SizedBox()
          : pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Text('Kassenschnitt ${period.label}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ),
      footer: (ctx) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Erstellt ${_stamp.format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          pw.Text('Seite ${ctx.pageNumber} von ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ]),
      ),
      build: (ctx) => [
        pw.Text(orgName, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        pw.SizedBox(height: 2),
        pw.Text('Kassenschnitt', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.Container(width: 48, height: 3, color: accent, margin: const pw.EdgeInsets.symmetric(vertical: 8)),
        pw.Text(period.label, style: const pw.TextStyle(fontSize: 12)),
        pw.SizedBox(height: 16),

        pw.Row(children: [
          kpi('Gesamt', Money.format(summary.totalCents), strong: true),
          pw.SizedBox(width: 6),
          kpi('Bar', Money.format(summary.cashCents)),
          pw.SizedBox(width: 6),
          kpi('Karte', Money.format(summary.cardCents)),
        ]),
        pw.SizedBox(height: 6),
        pw.Row(children: [
          kpi('Belege', '${summary.receipts}'),
          pw.SizedBox(width: 6),
          kpi('Artikel', '${summary.itemCount}'),
          pw.SizedBox(width: 6),
          kpi('Durchschnitt je Beleg', Money.format(summary.averageReceiptCents)),
        ]),

        section('Kassenbestand'),
        pw.TableHelper.fromTextArray(
          headers: const ['Posten', 'Betrag'],
          data: [
            ['Kassenstart', Money.format(opening)],
            ['Barumsatz', Money.format(summary.cashCents)],
            ['Einlagen', Money.format(deposit)],
            ['Entnahmen', '- ${Money.format(withdrawal)}'],
            ['Kasseninhalt rechnerisch', Money.format(drawerCents)],
          ],
          headerStyle: head,
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerRight},
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        ),

        if (summary.days.length > 1) ...[
          section('Tage'),
          pw.TableHelper.fromTextArray(
            headers: const ['Tag', 'Belege', 'Bar', 'Karte', 'Gesamt'],
            data: summary.days
                .map((d) => [
                      d.day,
                      '${d.receipts}',
                      Money.format(d.cashCents),
                      Money.format(d.cardCents),
                      Money.format(d.totalCents),
                    ])
                .toList(),
            headerStyle: head,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            },
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          ),
        ],

        section('Artikel'),
        if (summary.items.isEmpty)
          pw.Text('Keine Verkäufe in diesem Zeitraum.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))
        else
          pw.TableHelper.fromTextArray(
            headers: const ['Artikel', 'Kategorie', 'Menge', 'Umsatz'],
            data: summary.items
                .map((i) => [i.name, i.category, '${i.qty}', Money.format(i.totalCents)])
                .toList(),
            headerStyle: head,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
            columnWidths: {
              0: const pw.FlexColumnWidth(4),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(2),
            },
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          ),
      ],
    ));

    return doc.save();
  }

  /// Erzeugt das PDF und uebergibt es dem Druckdialog des Geraets.
  ///
  /// Anders als [sharePdf] landet das PDF damit direkt im Drucksystem von
  /// Android: dort steht jeder Drucker zur Auswahl, den das Geraet kennt -
  /// der Drucker im WLAN ebenso wie "Als PDF speichern". Das ist der Weg fuer
  /// den Kassenschnitt auf einem gewoehnlichen Drucker; der Bondrucker laeuft
  /// weiterhin ueber ReceiptService und ESC/POS.
  static Future<void> printPdf({
    required ReportPeriod period,
    required SalesSummary summary,
    required Map<String, CashDay> cashDays,
    required int drawerCents,
    String orgName = 'TSV KassenApp',
  }) async {
    final bytes = await buildPdf(
      period: period,
      summary: summary,
      cashDays: cashDays,
      drawerCents: drawerCents,
      orgName: orgName,
    );
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'Kassenschnitt-${period.fileLabel}',
      format: PdfPageFormat.a4,
    );
  }

  /// Erzeugt das PDF und oeffnet den Teilen-Dialog.
  static Future<void> sharePdf({
    required ReportPeriod period,
    required SalesSummary summary,
    required Map<String, CashDay> cashDays,
    required int drawerCents,
    String orgName = 'TSV KassenApp',
  }) async {
    final bytes = await buildPdf(
      period: period,
      summary: summary,
      cashDays: cashDays,
      drawerCents: drawerCents,
      orgName: orgName,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Kassenschnitt-${period.fileLabel}.pdf',
    );
  }
}
