import 'package:cloud_firestore/cloud_firestore.dart';

class TablesRepo {
  final _db = FirebaseFirestore.instance;

  Stream<List<Map<String, dynamic>>> streamAll() {
    return _db.collection('tables').orderBy('name').snapshots().map((snap) => snap.docs.map((d) {
          final m = d.data();
          return {
            'id': d.id,
            'name': m['name'] as String? ?? d.id,
            'row': (m['row'] as num?)?.toInt() ?? 0,
            'col': (m['col'] as num?)?.toInt() ?? 0,
            'active': (m['active'] as bool?) ?? true,
          };
        }).toList());
  }

  Future<void> add({required String name, required int row, required int col, bool active = true}) async {
    await _db.collection('tables').add({
      'name': name,
      'row': row,
      'col': col,
      'active': active,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> update(String id, {required String name, required int row, required int col, required bool active}) async {
    await _db.collection('tables').doc(id).set({
      'name': name,
      'row': row,
      'col': col,
      'active': active,
    }, SetOptions(merge: true));
  }

  Future<void> delete(String id) async {
    await _db.collection('tables').doc(id).delete();
  }
}
