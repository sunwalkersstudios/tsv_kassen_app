import 'package:cloud_firestore/cloud_firestore.dart';

/// Zugriff auf die Verkaufsdokumente.
///
/// Das Feld `day` ist ein String im Format yyyy-MM-dd. Weil dieses Format
/// lexikografisch in derselben Reihenfolge sortiert wie chronologisch,
/// funktionieren Bereichsabfragen darauf ohne Umweg ueber Zeitstempel.
class SalesRepo {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('sales');

  // ---------------------------------------------------------------- Einzeltag

  Stream<List<Map<String, dynamic>>> streamSalesForDay(String day) {
    return _col
        .where('day', isEqualTo: day)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<List<Map<String, dynamic>>> fetchSalesForDay(String day) async {
    final snap = await _col.where('day', isEqualTo: day).get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  // --------------------------------------------------------------- Zeitraeume

  /// Verkaeufe eines Zeitraums, beide Grenzen einschliesslich.
  Stream<List<Map<String, dynamic>>> streamSalesForRange(String fromDay, String toDay) {
    return _rangeQuery(fromDay, toDay)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<List<Map<String, dynamic>>> fetchSalesForRange(String fromDay, String toDay) async {
    final snap = await _rangeQuery(fromDay, toDay).get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Query<Map<String, dynamic>> _rangeQuery(String fromDay, String toDay) => _col
      .where('day', isGreaterThanOrEqualTo: fromDay)
      .where('day', isLessThanOrEqualTo: toDay)
      .orderBy('day');

  // ------------------------------------------------------------------ Grenzen

  /// Aeltester Tag mit Umsatz, oder null wenn noch nichts verkauft wurde.
  /// Begrenzt den Datumswaehler nach unten, damit niemand durch leere
  /// Zeitraeume blaettert.
  Future<String?> firstSaleDay() async {
    final snap = await _col.orderBy('day').limit(1).get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data()['day'] as String?;
  }

  /// Juengster Tag mit Umsatz.
  Future<String?> lastSaleDay() async {
    final snap = await _col.orderBy('day', descending: true).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data()['day'] as String?;
  }
}
