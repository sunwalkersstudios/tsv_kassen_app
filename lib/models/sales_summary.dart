import '../util/money.dart';

/// Ein Artikel in der Auswertung.
class ItemLine {
  final String name;
  final String category;
  final String route;
  int qty;
  int totalCents;

  ItemLine({
    required this.name,
    this.category = '',
    this.route = '',
    this.qty = 0,
    this.totalCents = 0,
  });
}

/// Umsatz eines einzelnen Tages innerhalb eines laengeren Zeitraums.
class DayLine {
  final String day;
  int receipts;
  int cashCents;
  int cardCents;

  DayLine({required this.day, this.receipts = 0, this.cashCents = 0, this.cardCents = 0});

  int get totalCents => cashCents + cardCents;
}

/// Auswertung einer Menge von Verkaufsdokumenten.
///
/// Bildschirm, Druck und Export leiten ihre Zahlen aus derselben Klasse ab,
/// damit sie nicht auseinanderlaufen koennen.
class SalesSummary {
  int receipts = 0;
  int cashCents = 0;
  int cardCents = 0;

  /// Artikel nach Umsatz absteigend.
  final List<ItemLine> items = [];

  /// Tage mit Umsatz, chronologisch.
  final List<DayLine> days = [];

  int get totalCents => cashCents + cardCents;
  int get itemCount => items.fold(0, (a, i) => a + i.qty);
  int get averageReceiptCents => receipts == 0 ? 0 : (totalCents / receipts).round();

  bool get isEmpty => receipts == 0;

  /// Baut die Auswertung aus den Rohdokumenten der Collection `sales`.
  ///
  /// `total` und `lineTotal` liegen dort noch als Fliesskommazahl; sie werden
  /// beim Einlesen einmalig in Cent umgerechnet und danach nur noch ganzzahlig
  /// weiterverarbeitet.
  factory SalesSummary.fromSales(List<Map<String, dynamic>> sales) {
    final s = SalesSummary._();
    final itemMap = <String, ItemLine>{};
    final dayMap = <String, DayLine>{};

    for (final sale in sales) {
      final cents = Money.fromDouble(sale['total'] as num?);
      final isCard = (sale['paymentMethod'] ?? 'cash').toString() == 'card';
      final day = (sale['day'] ?? '').toString();

      s.receipts++;
      if (isCard) {
        s.cardCents += cents;
      } else {
        s.cashCents += cents;
      }

      if (day.isNotEmpty) {
        final dl = dayMap.putIfAbsent(day, () => DayLine(day: day));
        dl.receipts++;
        if (isCard) {
          dl.cardCents += cents;
        } else {
          dl.cashCents += cents;
        }
      }

      for (final raw in (sale['items'] as List?) ?? const []) {
        final it = Map<String, dynamic>.from(raw as Map);
        final name = (it['name'] ?? it['menuItemId'] ?? '(ohne Namen)').toString();
        final qty = (it['qty'] as num?)?.toInt() ?? 1;
        final lineCents = it['lineTotal'] != null
            ? Money.fromDouble(it['lineTotal'] as num?)
            : Money.fromDouble((it['price'] as num?)) * qty;
        final line = itemMap.putIfAbsent(
          name,
          () => ItemLine(
            name: name,
            category: (it['category'] ?? '').toString(),
            route: (it['route'] ?? '').toString(),
          ),
        );
        line.qty += qty;
        line.totalCents += lineCents;
      }
    }

    s.items
      ..addAll(itemMap.values)
      ..sort((a, b) => b.totalCents.compareTo(a.totalCents));
    s.days
      ..addAll(dayMap.values)
      ..sort((a, b) => a.day.compareTo(b.day));
    return s;
  }

  SalesSummary._();
}
