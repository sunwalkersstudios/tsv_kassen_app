import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/entities.dart';

class MenuRepo {
  final _db = FirebaseFirestore.instance;

  Stream<List<MenuItemEntity>> streamAll({String? eventId}) {
    Query<Map<String, dynamic>> q = _db.collection('menu');
    // Use 'base' sentinel for base menu to avoid null filtering issues
    final key = eventId ?? 'base';
    q = q.where('eventId', isEqualTo: key);
    return q.snapshots().map((snap) => snap.docs.map((d) {
          final m = d.data();
          final ev = m['eventId'] as String?;
          return MenuItemEntity(
            id: d.id,
            name: m['name'] as String,
            price: (m['price'] as num).toDouble(),
            category: m['category'] as String,
            route: m['route'] as String,
            eventId: ev == 'base' ? null : ev,
          );
        }).toList());
  }

  // For service screens (Kellner): show base + active event-specific items together
  Stream<List<MenuItemEntity>> streamForService({String? activeEventId}) {
    final col = _db.collection('menu');
    final keys = <String>["base", if (activeEventId != null) activeEventId];
    final q = col.where('eventId', whereIn: keys);
    return q.snapshots().map((snap) => snap.docs.map((d) {
          final m = d.data();
          final ev = m['eventId'] as String?;
          return MenuItemEntity(
            id: d.id,
            name: m['name'] as String,
            price: (m['price'] as num).toDouble(),
            category: m['category'] as String,
            route: m['route'] as String,
            eventId: ev == 'base' ? null : ev,
          );
        }).toList());
  }

  Future<void> addItem({
    required String name,
    required double price,
    required String category,
    required String route,
    String? eventId,
  }) async {
    await _db.collection('menu').add({
      'name': name,
      'price': price,
      'category': category,
      'route': route,
      'eventId': eventId ?? 'base',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateItem(MenuItemEntity e) async {
    await _db.collection('menu').doc(e.id).set({
      'name': e.name,
      'price': e.price,
      'category': e.category,
      'route': e.route,
      'eventId': e.eventId,
    }, SetOptions(merge: true));
  }

  Future<void> deleteItem(String id) async {
    await _db.collection('menu').doc(id).delete();
  }
}
