import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/cash_day.dart';

/// Zugriff auf `cashDays/{yyyy-MM-dd}` - Kassenstart, Einlagen, Entnahmen.
class CashDayRepo {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('cashDays');

  /// Laufende Aktualisierung eines einzelnen Tages.
  Stream<CashDay> streamDay(String day) => _col.doc(day).snapshots().map(
        (snap) => CashDay.fromMap(day, snap.data()),
      );

  Future<CashDay> fetchDay(String day) async {
    final snap = await _col.doc(day).get();
    return CashDay.fromMap(day, snap.data());
  }

  /// Alle hinterlegten Tage eines Zeitraums, jeweils einschliesslich.
  /// Tage ohne Eintrag fehlen in der Rueckgabe.
  Future<Map<String, CashDay>> fetchRange(String fromDay, String toDay) async {
    final snap = await _col
        .orderBy(FieldPath.documentId)
        .startAt([fromDay])
        .endAt([toDay])
        .get();
    return {
      for (final d in snap.docs) d.id: CashDay.fromMap(d.id, d.data()),
    };
  }

  /// Schreibt die Tageswerte. Vorhandene Felder bleiben erhalten.
  Future<void> save(CashDay day) async {
    await _col.doc(day.day).set({
      ...day.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid,
    }, SetOptions(merge: true));
  }

  /// Setzt die Tageswerte zurueck, ohne das Dokument zu entfernen -
  /// so bleibt nachvollziehbar, dass jemand den Tag bewusst geleert hat.
  Future<void> reset(String day) async {
    await save(CashDay.empty(day));
  }
}
