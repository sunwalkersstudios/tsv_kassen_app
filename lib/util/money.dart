import 'package:intl/intl.dart';

/// Rechnen mit Geld in ganzzahligen Cent.
///
/// Fliesskommazahlen sind fuer Betraege ungeeignet: 0.1 + 0.2 ergibt nicht
/// exakt 0.3, und der Fehler waechst mit jeder Summierung. Alle Betraege in
/// neuem Code werden deshalb als `int` in Cent gefuehrt und erst zur Anzeige
/// umgerechnet.
class Money {
  Money._();

  static final NumberFormat _fmt = NumberFormat.currency(locale: 'de_DE', symbol: '€');
  static final NumberFormat _plain = NumberFormat('0.00', 'de_DE');

  /// Formatiert Cent als Betrag mit Waehrung: 1234 -> "12,34 €"
  static String format(int cents) => _fmt.format(cents / 100);

  /// Formatiert Cent ohne Waehrungszeichen: 1234 -> "12,34"
  static String plain(int cents) => _plain.format(cents / 100);

  /// Formatiert Cent fuer CSV mit Punkt als Dezimaltrenner: 1234 -> "12.34"
  static String csv(int cents) => (cents / 100).toStringAsFixed(2);

  /// Ein Punkt mit genau drei Ziffern dahinter und einer fuehrenden Ziffer
  /// ungleich null davor - also ein Tausenderpunkt wie in "1.000".
  /// Die fuehrende Null schliesst "0.500" aus, das jemand als 0,50 meint.
  static final RegExp _thousandsDot = RegExp(r'^[1-9]\d{0,2}(\.\d{3})+$');

  /// Liest eine Nutzereingabe als Cent. Akzeptiert Komma und Punkt,
  /// ignoriert Leerzeichen und ein angehaengtes Euro-Zeichen.
  /// Gibt null zurueck, wenn nichts Sinnvolles erkennbar ist.
  ///
  /// Zur Mehrdeutigkeit des Punktes: "1.234,56" ist eindeutig deutsch, weil ein
  /// Komma folgt. Steht kein Komma da, ist "1.000" zweideutig - deutsch tausend
  /// oder englisch eins Komma null. In einer deutschen Kasse wiegt der Irrtum
  /// "1.000 wird zu 1,00 EUR" schwerer, deshalb gilt ein Punkt mit genau drei
  /// Ziffern dahinter als Tausenderpunkt. In allen anderen Faellen - "12.34",
  /// "0.500" - bleibt der Punkt ein Dezimaltrenner.
  static int? parse(String input) {
    var s = input.trim().replaceAll('€', '').replaceAll(' ', '');
    if (s.isEmpty) return null;
    if (s.contains(',')) {
      // Deutsche Schreibweise: Punkte sind Tausendertrenner.
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else if (_thousandsDot.hasMatch(s)) {
      s = s.replaceAll('.', '');
    }
    final v = double.tryParse(s);
    if (v == null) return null;
    return (v * 100).round();
  }

  /// Wandelt einen Fliesskommabetrag aus Altbestaenden in Cent.
  static int fromDouble(num? value) => ((value ?? 0).toDouble() * 100).round();

  /// Liest einen Geldbetrag aus einem Firestore-Dokument als Cent.
  ///
  /// Bevorzugt das Cent-Feld. Fehlt es, wird das alte Fliesskommafeld gelesen
  /// und umgerechnet - so bleiben Dokumente aus der Zeit vor der Umstellung
  /// lesbar, statt stillschweigend 0,00 EUR zu ergeben.
  ///
  /// Diese eine Stelle kennt beide Feldnamen; alle Leser gehen darueber,
  /// damit die Rueckfalllogik nicht ueber die Codebasis verstreut liegt.
  static int readCents(Map<String, dynamic>? m, String centsKey, String legacyKey) {
    if (m == null) return 0;
    final c = m[centsKey];
    if (c is num) return c.round();
    return fromDouble(m[legacyKey] as num?);
  }

  /// Betrag eines Verkaufsdokuments.
  static int saleTotal(Map<String, dynamic>? sale) => readCents(sale, 'totalCents', 'total');

  /// Einzelpreis einer Position.
  static int itemPrice(Map<String, dynamic>? item) => readCents(item, 'priceCents', 'price');

  /// Zeilensumme einer Position. Fehlt sie, wird sie aus Preis mal Menge
  /// gebildet.
  static int itemLineTotal(Map<String, dynamic>? item) {
    if (item == null) return 0;
    if (item['lineTotalCents'] is num) return (item['lineTotalCents'] as num).round();
    if (item['lineTotal'] is num) return fromDouble(item['lineTotal'] as num);
    final qty = (item['qty'] as num?)?.toInt() ?? 1;
    return itemPrice(item) * qty;
  }
}
