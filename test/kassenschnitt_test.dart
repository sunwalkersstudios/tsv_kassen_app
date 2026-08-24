import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tsv/models/cash_day.dart';
import 'package:tsv/models/report_period.dart';
import 'package:tsv/models/sales_summary.dart';
import 'package:tsv/util/app_lock.dart';
import 'package:tsv/util/money.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('de_DE', null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Money', () {
    test('liest deutsche und englische Schreibweise', () {
      expect(Money.parse('12,34'), 1234);
      expect(Money.parse('12.34'), 1234);
      expect(Money.parse('12'), 1200);
      expect(Money.parse('0,05'), 5);
    });

    test('verkraftet Tausenderpunkt, Euro-Zeichen und Leerzeichen', () {
      expect(Money.parse('1.234,56'), 123456);
      expect(Money.parse(' 9,90 € '), 990);
      expect(Money.parse('1.000'), 100000);
    });

    test('deutet den Punkt bei Mehrdeutigkeit als Tausendertrenner', () {
      // genau drei Ziffern nach dem Punkt, fuehrende Ziffer ungleich null
      expect(Money.parse('1.000'), 100000);
      expect(Money.parse('12.345'), 1234500);
      // alles andere bleibt Dezimaltrenner
      expect(Money.parse('12.34'), 1234);
      expect(Money.parse('0.500'), 50);
      expect(Money.parse('1.5'), 150);
    });

    test('gibt null bei unbrauchbarer Eingabe', () {
      expect(Money.parse(''), isNull);
      expect(Money.parse('   '), isNull);
      expect(Money.parse('abc'), isNull);
    });

    test('rundet kaufmaennisch statt abzuschneiden', () {
      expect(Money.parse('0,005'), 1);
      expect(Money.fromDouble(19.999), 2000);
      expect(Money.fromDouble(0.1 + 0.2), 30);
    });

    test('formatiert fuer Anzeige und CSV', () {
      expect(Money.csv(1234), '12.34');
      expect(Money.plain(1234), '12,34');
      expect(Money.format(0), contains('0,00'));
    });
  });

  group('ReportPeriod', () {
    // Mittwoch, 12. November 2025
    final mittwoch = DateTime(2025, 11, 12);

    test('Tag umfasst genau einen Tag', () {
      final p = ReportPeriod(PeriodKind.day, mittwoch);
      expect(p.fromKey, '2025-11-12');
      expect(p.toKey, '2025-11-12');
      expect(p.isSingleDay, isTrue);
    });

    test('Woche laeuft von Montag bis Sonntag', () {
      final p = ReportPeriod(PeriodKind.week, mittwoch);
      expect(p.fromKey, '2025-11-10'); // Montag
      expect(p.toKey, '2025-11-16');   // Sonntag
    });

    test('Monat endet am letzten Tag, auch im Februar', () {
      expect(ReportPeriod(PeriodKind.month, mittwoch).fromKey, '2025-11-01');
      expect(ReportPeriod(PeriodKind.month, mittwoch).toKey, '2025-11-30');
      // Schaltjahr
      final feb = ReportPeriod(PeriodKind.month, DateTime(2024, 2, 15));
      expect(feb.toKey, '2024-02-29');
      // kein Schaltjahr
      expect(ReportPeriod(PeriodKind.month, DateTime(2025, 2, 15)).toKey, '2025-02-28');
    });

    test('Jahr umfasst den ganzen Kalenderjahrgang', () {
      final p = ReportPeriod(PeriodKind.year, mittwoch);
      expect(p.fromKey, '2025-01-01');
      expect(p.toKey, '2025-12-31');
    });

    test('shift bewegt sich in der jeweiligen Einheit', () {
      expect(ReportPeriod(PeriodKind.day, mittwoch).shift(1).fromKey, '2025-11-13');
      expect(ReportPeriod(PeriodKind.day, mittwoch).shift(-1).fromKey, '2025-11-11');
      expect(ReportPeriod(PeriodKind.week, mittwoch).shift(-1).fromKey, '2025-11-03');
      expect(ReportPeriod(PeriodKind.month, mittwoch).shift(1).fromKey, '2025-12-01');
      // ueber die Jahresgrenze
      expect(ReportPeriod(PeriodKind.month, DateTime(2025, 12, 5)).shift(1).fromKey, '2026-01-01');
      expect(ReportPeriod(PeriodKind.year, mittwoch).shift(1).fromKey, '2026-01-01');
    });

    test('Wechsel der Einheit behaelt den Ankertag', () {
      final p = ReportPeriod(PeriodKind.day, mittwoch).withKind(PeriodKind.month);
      expect(p.fromKey, '2025-11-01');
      expect(p.kindLabel, 'Monat');
    });

    test('Dateiname ist ohne Sonderzeichen', () {
      expect(ReportPeriod(PeriodKind.day, mittwoch).fileLabel, '2025-11-12');
      expect(ReportPeriod(PeriodKind.month, mittwoch).fileLabel, '2025-11');
      expect(ReportPeriod(PeriodKind.year, mittwoch).fileLabel, '2025');
      expect(ReportPeriod(PeriodKind.week, mittwoch).fileLabel, matches(r'^2025-KW\d{2}$'));
    });
  });

  group('SalesSummary', () {
    List<Map<String, dynamic>> beispiel() => [
          {
            'day': '2025-11-12',
            'total': 12.50,
            'paymentMethod': 'cash',
            'items': [
              {'name': 'Schnitzel', 'category': 'Speisen', 'route': 'kitchen', 'qty': 1, 'lineTotal': 12.50},
            ],
          },
          {
            'day': '2025-11-12',
            'total': 7.00,
            'paymentMethod': 'card',
            'items': [
              {'name': 'Bier', 'category': 'Getränke', 'route': 'bar', 'qty': 2, 'lineTotal': 7.00},
            ],
          },
          {
            'day': '2025-11-13',
            'total': 3.50,
            'paymentMethod': 'cash',
            'items': [
              {'name': 'Bier', 'category': 'Getränke', 'route': 'bar', 'qty': 1, 'lineTotal': 3.50},
            ],
          },
        ];

    test('summiert Bar und Karte getrennt', () {
      final s = SalesSummary.fromSales(beispiel());
      expect(s.receipts, 3);
      expect(s.cashCents, 1600); // 12,50 + 3,50
      expect(s.cardCents, 700);
      expect(s.totalCents, 2300);
    });

    test('fasst Artikel ueber Belege hinweg zusammen', () {
      final s = SalesSummary.fromSales(beispiel());
      final bier = s.items.firstWhere((i) => i.name == 'Bier');
      expect(bier.qty, 3);
      expect(bier.totalCents, 1050);
      expect(s.itemCount, 4);
    });

    test('sortiert Artikel nach Umsatz absteigend', () {
      final s = SalesSummary.fromSales(beispiel());
      expect(s.items.first.name, 'Schnitzel'); // 12,50 vor 10,50
    });

    test('gruppiert nach Tag, chronologisch', () {
      final s = SalesSummary.fromSales(beispiel());
      expect(s.days.map((d) => d.day).toList(), ['2025-11-12', '2025-11-13']);
      expect(s.days.first.totalCents, 1950);
      expect(s.days.last.receipts, 1);
    });

    test('leere Eingabe ergibt leere Auswertung', () {
      final s = SalesSummary.fromSales([]);
      expect(s.isEmpty, isTrue);
      expect(s.totalCents, 0);
      expect(s.averageReceiptCents, 0); // keine Division durch null
    });

    test('faellt auf Preis mal Menge zurueck, wenn lineTotal fehlt', () {
      final s = SalesSummary.fromSales([
        {
          'day': '2025-11-12',
          'total': 6.00,
          'paymentMethod': 'cash',
          'items': [
            {'name': 'Cola', 'qty': 2, 'price': 3.00},
          ],
        },
      ]);
      expect(s.items.single.totalCents, 600);
    });
  });

  group('CashDay', () {
    test('rechnet den Kassenbestand', () {
      const d = CashDay(
        day: '2025-11-12',
        openingCents: 15000,
        depositCents: 2000,
        withdrawalCents: 5000,
      );
      // 150 + 320 Barumsatz + 20 - 50
      expect(d.drawerCents(32000), 44000);
    });

    test('leerer Tag hat keine Eintraege', () {
      expect(CashDay.empty('2025-11-12').hasEntries, isFalse);
      expect(CashDay.empty('2025-11-12').drawerCents(1000), 1000);
    });

    test('erkennt gesetzte Werte', () {
      expect(const CashDay(day: 'x', openingCents: 1).hasEntries, isTrue);
      expect(const CashDay(day: 'x', note: 'Differenz').hasEntries, isTrue);
    });

    test('liest fehlende Felder als Null', () {
      final d = CashDay.fromMap('2025-11-12', null);
      expect(d.openingCents, 0);
      expect(d.note, '');
    });
  });

  group('AppLock', () {
    test('ohne Einrichtung gibt es keine PIN', () async {
      expect(await AppLock.hasPin(), isFalse);
      expect(await AppLock.verify('1234'), isFalse);
    });

    test('legt eine PIN an und prueft sie', () async {
      expect(await AppLock.setPin('2468'), isNull);
      expect(await AppLock.hasPin(), isTrue);
      expect(await AppLock.verify('2468'), isTrue);
      expect(await AppLock.verify('1357'), isFalse);
    });

    test('weist zu kurze, zu lange und nicht-numerische PINs ab', () async {
      expect(await AppLock.setPin('123'), isNotNull);
      expect(await AppLock.setPin('123456789'), isNotNull);
      expect(await AppLock.setPin('12a4'), isNotNull);
    });

    test('weist lauter gleiche Ziffern ab', () async {
      expect(await AppLock.setPin('1111'), isNotNull);
      expect(await AppLock.setPin('000000'), isNotNull);
    });

    test('speichert die PIN nicht im Klartext', () async {
      await AppLock.setPin('9753');
      final sp = await SharedPreferences.getInstance();
      final werte = sp.getKeys().map((k) => sp.get(k).toString()).join(' ');
      expect(werte.contains('9753'), isFalse);
    });

    test('gleiche PIN ergibt dank Salt unterschiedliche Ablage', () async {
      await AppLock.setPin('2468');
      final sp1 = await SharedPreferences.getInstance();
      final h1 = sp1.getString('lock.pinHash');
      SharedPreferences.setMockInitialValues({});
      await AppLock.setPin('2468');
      final sp2 = await SharedPreferences.getInstance();
      expect(sp2.getString('lock.pinHash'), isNot(h1));
    });

    test('entfernt die PIN wieder', () async {
      await AppLock.setPin('2468');
      await AppLock.clearPin();
      expect(await AppLock.hasPin(), isFalse);
      expect(await AppLock.verify('2468'), isFalse);
    });
  });
}
