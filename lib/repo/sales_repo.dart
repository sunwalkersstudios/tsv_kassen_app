import 'package:cloud_firestore/cloud_firestore.dart';

class SalesRepo {
  final _db = FirebaseFirestore.instance;

  // Stream sales for a given day key (YYYY-MM-DD)
  Stream<List<Map<String, dynamic>>> streamSalesForDay(String day) {
    return _db
        .collection('sales')
        .where('day', isEqualTo: day)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  // One-time fetch for exports and printing
  Future<List<Map<String, dynamic>>> fetchSalesForDay(String day) async {
    final snap = await _db.collection('sales').where('day', isEqualTo: day).get();
    return snap.docs.map((d) => d.data()).toList();
  }
}
