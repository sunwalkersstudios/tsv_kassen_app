import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/entities.dart';

class TicketsRepo {
  final _db = FirebaseFirestore.instance;

  // Open or create a non-paid ticket for table
  Future<String> openOrCreateTicket({required String tableId, required String serverId, String? tableName}) async {
    try {
      final snap = await _db
          .collection('tickets')
          .where('tableId', isEqualTo: tableId)
          .limit(10)
          .get()
          .timeout(const Duration(seconds: 6));
      // pick best non-paid candidate deterministically: prefer latest created
      final candidates = snap.docs.where((d) => ((d.data()['status'] as String?) ?? 'open') != 'paid').toList();
      if (candidates.isNotEmpty) {
        candidates.sort((a, b) {
          final ca = (a.data()['updatedAt'] as Timestamp?) ?? (a.data()['createdAt'] as Timestamp?);
          final cb = (b.data()['updatedAt'] as Timestamp?) ?? (b.data()['createdAt'] as Timestamp?);
          final da = ca?.toDate().millisecondsSinceEpoch ?? 0;
          final db = cb?.toDate().millisecondsSinceEpoch ?? 0;
          return db.compareTo(da); // newest first
        });
        final chosen = candidates.first;
        await chosen.reference.set({
          'serverId': serverId,
          if (tableName != null && tableName.isNotEmpty) 'tableName': tableName,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return chosen.id;
      }
      return await createTicket(tableId: tableId, serverId: serverId, tableName: tableName);
    } catch (e) {
      // Propagate so UI can show an error instead of spinning forever
      rethrow;
    }
  }

  Future<String> createTicket({required String tableId, required String serverId, String? tableName}) async {
    final doc = await _db.collection('tickets').add({
      'tableId': tableId,
      'serverId': serverId,
      if (tableName != null && tableName.isNotEmpty) 'tableName': tableName,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Fetch all unpaid tickets for a table directly from the server (no cache).
  /// Returns a list of maps containing minimal info: {id,status,updatedAt,createdAt,serverId,tableName}
  Future<List<Map<String, dynamic>>> fetchUnpaidTicketsForTable(String tableId) async {
    final snap = await _db
        .collection('tickets')
        .where('tableId', isEqualTo: tableId)
        .get(const GetOptions(source: Source.server));
    final list = snap.docs
        .where((d) => ((d.data()['status'] as String?) ?? 'open') != 'paid')
        .map((d) {
      final m = d.data();
      return {
        'id': d.id,
        'status': (m['status'] as String?) ?? 'open',
        'updatedAt': m['updatedAt'],
        'createdAt': m['createdAt'],
        'serverId': (m['serverId'] ?? '').toString(),
        'tableName': (m['tableName'] ?? '').toString(),
      };
    }).toList();
    list.sort((a, b) {
      final ta = (a['updatedAt'] as Timestamp?) ?? (a['createdAt'] as Timestamp?);
      final tb = (b['updatedAt'] as Timestamp?) ?? (b['createdAt'] as Timestamp?);
      final da = ta?.toDate().millisecondsSinceEpoch ?? 0;
      final db = tb?.toDate().millisecondsSinceEpoch ?? 0;
      return db.compareTo(da);
    });
    return list;
  }

  Stream<List<TicketItemEntity>> streamTicketItems(String ticketId) {
    return _db
        .collection('tickets')
        .doc(ticketId)
        .collection('items')
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final m = d.data();
              return TicketItemEntity(
                id: d.id,
                menuItemId: m['menuItemId'] as String,
                qty: (m['qty'] as num).toInt(),
                notes: (m['notes'] as String?) ?? '',
                route: m['route'] as String,
                status: _statusFromString(m['status'] as String? ?? 'open'),
              );
            }).toList());
  }

  Future<void> addItem({
    required String ticketId,
    required String tableId,
    required String menuItemId,
    required int qty,
    required String route,
    String? name,
    double? price,
    String? category,
    String notes = '',
  }) async {
    final parent = _db.collection('tickets').doc(ticketId);
    await parent.collection('items').add({
      'menuItemId': menuItemId,
      'qty': qty,
      'route': route,
      'notes': notes,
      if (name != null) 'name': name,
      if (price != null) 'price': price,
      if (category != null) 'category': category,
      'status': 'open',
      'tableId': tableId, // denormalize for collectionGroup queries
      'createdAt': FieldValue.serverTimestamp(),
    });
    // bump ticket updatedAt for deterministic reuse
    await parent.set({'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  Future<void> deleteItem({required String ticketId, required String itemId}) async {
    await _db.collection('tickets').doc(ticketId).collection('items').doc(itemId).delete();
  }

  Future<void> updateItemNotes({required String ticketId, required String itemId, required String notes}) async {
    await _db.collection('tickets').doc(ticketId).collection('items').doc(itemId).update({'notes': notes});
  }

  // Return raw item maps including denormalized fields like name, price, category.
  Future<List<Map<String, dynamic>>> getItemsRaw(String ticketId) async {
    final snap = await _db.collection('tickets').doc(ticketId).collection('items').get();
    return snap.docs.map((d) {
      final m = d.data();
      return {
        'id': d.id,
        ...m,
      };
    }).toList();
  }

  Future<void> sendTicket(String ticketId) async {
    final itemsSnap = await _db
        .collection('tickets')
        .doc(ticketId)
        .collection('items')
        .where('status', isEqualTo: 'open')
        .get();
    final batch = _db.batch();
    for (final d in itemsSnap.docs) {
      batch.update(d.reference, {'status': 'sentToKitchen'});
    }
    await batch.commit();
    // Update ticket doc only if it exists to avoid NOT_FOUND
    final ticketRef = _db.collection('tickets').doc(ticketId);
    final ticketSnap = await ticketRef.get();
    if (ticketSnap.exists) {
      await ticketRef.update({'status': 'sentToKitchen', 'updatedAt': FieldValue.serverTimestamp()});
    }
  }

  Future<void> markRouteReady(String ticketId, String route) async {
    final itemsRef = _db.collection('tickets').doc(ticketId).collection('items');
    // Query only by route to avoid composite index requirements; filter statuses client-side
    final itemsSnap = await itemsRef.where('route', isEqualTo: route).get();
    final batch = _db.batch();
    for (final d in itemsSnap.docs) {
      final st = (d.data()['status'] as String?) ?? 'open';
      if (st == 'open' || st == 'sentToKitchen') {
        batch.update(d.reference, {'status': 'ready'});
      }
    }
    await batch.commit();
    // Check if all items ready
    final ticketDocRef = _db.collection('tickets').doc(ticketId);
    final ticketSnap = await ticketDocRef.get();
    if (!ticketSnap.exists) {
      return; // ticket might have been deleted/was a demo id; nothing to update
    }
    // Mark this route as ready on the ticket document if there were items for it
    if (itemsSnap.docs.isNotEmpty) {
      await ticketDocRef.set({
        'routesReady': {route: true},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    final allSnap = await itemsRef.get();
    final allReady = allSnap.docs.isNotEmpty && allSnap.docs.every((d) => (d.data()['status'] as String) == 'ready');
    if (allReady) {
      await ticketDocRef.update({'status': 'ready'});
    }
  }

  Future<String?> getTicketTableId(String ticketId) async {
    final doc = await _db.collection('tickets').doc(ticketId).get();
    return (doc.data() ?? const {})['tableId'] as String?;
  }

  Future<String?> getTicketTableName(String ticketId) async {
    final doc = await _db.collection('tickets').doc(ticketId).get();
    return (doc.data() ?? const {})['tableName'] as String?;
  }

  
  
  /// Pay all non-paid items on a ticket. Returns generated saleId.
  Future<String> markTicketPaid(String ticketId, {String paymentMethod = 'cash'}) async {
    final ticketRef = _db.collection('tickets').doc(ticketId);
    final tSnap = await ticketRef.get();
    final tData = tSnap.data() ?? {};
    final tableId = (tData['tableId'] as String?) ?? '';
    final tableName = (tData['tableName'] as String?) ?? '';
    final serverId = (tData['serverId'] as String?) ?? '';

    // Load items to compute totals and capture sale lines (only items not already paid)
    final itemsSnap = await ticketRef.collection('items').get();
    double total = 0;
    final saleItems = <Map<String, dynamic>>[];
    final toMarkPaid = <DocumentReference>[];
    for (final d in itemsSnap.docs) {
      final m = d.data();
      final st = (m['status'] as String?) ?? 'open';
      if (st == 'paid') continue;
      final qty = (m['qty'] as num?)?.toInt() ?? 1;
      final price = (m['price'] as num?)?.toDouble() ?? 0.0;
      final lineTotal = price * qty;
      total += lineTotal;
      saleItems.add({
        'menuItemId': (m['menuItemId'] ?? '').toString(),
        'name': (m['name'] ?? '').toString(),
        'category': (m['category'] ?? '').toString(),
        'route': (m['route'] ?? '').toString(),
        'qty': qty,
        'price': price,
        'lineTotal': lineTotal,
      });
      toMarkPaid.add(d.reference);
    }

    // Day key for quick queries (YYYY-MM-DD)
    final now = DateTime.now();
    final day = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Write sale doc with generated id (support multiple partial payments)
    final saleRef = await _db.collection('sales').add({
      'ticketId': ticketId,
      'tableId': tableId,
      'tableName': tableName,
      'serverId': serverId,
      'paidAt': FieldValue.serverTimestamp(),
      'day': day,
      'total': total,
      'paymentMethod': paymentMethod,
      'items': saleItems,
    });

    // Mark included items as paid
    final batch = _db.batch();
    for (final ref in toMarkPaid) {
      batch.update(ref, {'status': 'paid', 'paidAt': FieldValue.serverTimestamp()});
    }
    await batch.commit();

    // If all items are paid, mark ticket as paid
    final remaining = await ticketRef.collection('items').where('status', isNotEqualTo: 'paid').limit(1).get();
    if (remaining.docs.isEmpty) {
      await ticketRef.update({'status': 'paid', 'paidAt': FieldValue.serverTimestamp()});
    }

    return saleRef.id;
  }

  /// Pay a selected subset of items. Returns saleId.
  Future<String> paySelectedItems(String ticketId, List<String> itemIds, {String paymentMethod = 'cash'}) async {
    if (itemIds.isEmpty) {
      return await markTicketPaid(ticketId, paymentMethod: paymentMethod);
    }
    final ticketRef = _db.collection('tickets').doc(ticketId);
    final tSnap = await ticketRef.get();
    final tData = tSnap.data() ?? {};
    final tableId = (tData['tableId'] as String?) ?? '';
    final tableName = (tData['tableName'] as String?) ?? '';
    final serverId = (tData['serverId'] as String?) ?? '';

    double total = 0;
    final saleItems = <Map<String, dynamic>>[];
    final toMarkPaid = <DocumentReference>[];
    for (final itemId in itemIds) {
      final ref = ticketRef.collection('items').doc(itemId);
      final snap = await ref.get();
      if (!snap.exists) continue;
      final m = snap.data()!;
      if ((m['status'] as String?) == 'paid') continue;
      final qty = (m['qty'] as num?)?.toInt() ?? 1;
      final price = (m['price'] as num?)?.toDouble() ?? 0.0;
      final lineTotal = price * qty;
      total += lineTotal;
      saleItems.add({
        'menuItemId': (m['menuItemId'] ?? '').toString(),
        'name': (m['name'] ?? '').toString(),
        'category': (m['category'] ?? '').toString(),
        'route': (m['route'] ?? '').toString(),
        'qty': qty,
        'price': price,
        'lineTotal': lineTotal,
      });
      toMarkPaid.add(ref);
    }

    final now = DateTime.now();
    final day = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final saleRef = await _db.collection('sales').add({
      'ticketId': ticketId,
      'tableId': tableId,
      'tableName': tableName,
      'serverId': serverId,
      'paidAt': FieldValue.serverTimestamp(),
      'day': day,
      'total': total,
      'paymentMethod': paymentMethod,
      'items': saleItems,
    });
    final batch = _db.batch();
    for (final ref in toMarkPaid) {
      batch.update(ref, {'status': 'paid', 'paidAt': FieldValue.serverTimestamp()});
    }
    await batch.commit();

    // If all items are paid, mark ticket as paid
    final remaining = await ticketRef.collection('items').where('status', isNotEqualTo: 'paid').limit(1).get();
    if (remaining.docs.isEmpty) {
      await ticketRef.update({'status': 'paid', 'paidAt': FieldValue.serverTimestamp()});
    }
    return saleRef.id;
  }

  // Stream table IDs having at least one non-paid ticket in 'ready' for this server
  Stream<Set<String>> streamReadyTablesForServer(String serverId) {
    return _db
        .collection('tickets')
        .where('serverId', isEqualTo: serverId)
        .snapshots()
        .map((snap) {
      final readyTables = <String>{};
      for (final d in snap.docs) {
        final data = d.data();
        final status = (data['status'] as String?) ?? 'open';
        final tableId = (data['tableId'] as String?) ?? '';
        if (tableId.isEmpty) continue;
        if (status == 'ready') {
          readyTables.add(tableId);
        }
      }
      return readyTables;
    });
  }

  // Stream table IDs having at least one non-paid ticket in 'ready' (any server)
  Stream<Set<String>> streamReadyTablesAll() {
    return _db
        .collection('tickets')
        .snapshots()
        .map((snap) {
      final readyTables = <String>{};
      for (final d in snap.docs) {
        final data = d.data();
        final status = (data['status'] as String?) ?? 'open';
        final tableId = (data['tableId'] as String?) ?? '';
        if (tableId.isEmpty) continue;
        if (status == 'ready') {
          readyTables.add(tableId);
        }
      }
      return readyTables;
    });
  }

  // Stream per-table readiness flags per route and billable (overall ready) for this server
  // Returns a map: { tableId: { 'kitchen': bool, 'bar': bool, 'billable': bool } }
  Stream<Map<String, Map<String, bool>>> streamRouteFlagsForServer(String serverId) {
    return _db
        .collection('tickets')
        .where('serverId', isEqualTo: serverId)
        .snapshots()
        .map((snap) {
      final result = <String, Map<String, bool>>{};
      for (final d in snap.docs) {
        final data = d.data();
        final status = (data['status'] as String?) ?? 'open';
        if (status == 'paid') continue; // ignore paid
        final tableId = (data['tableId'] as String?) ?? '';
        if (tableId.isEmpty) continue;
        final rr = (data['routesReady'] as Map<String, dynamic>?) ?? const {};
        final kReady = rr['kitchen'] == true;
        final bReady = rr['bar'] == true;
        final billable = status == 'ready';
        final entry = result.putIfAbsent(tableId, () => {'kitchen': false, 'bar': false, 'billable': false});
        entry['kitchen'] = entry['kitchen']! || kReady;
        entry['bar'] = entry['bar']! || bReady;
        entry['billable'] = entry['billable']! || billable;
      }
      return result;
    });
  }

  // Same as above, but across all servers (any owner)
  Stream<Map<String, Map<String, bool>>> streamRouteFlagsAll() {
    return _db
        .collection('tickets')
        .snapshots()
        .map((snap) {
      final result = <String, Map<String, bool>>{};
      for (final d in snap.docs) {
        final data = d.data();
        final status = (data['status'] as String?) ?? 'open';
        if (status == 'paid') continue; // ignore paid
        final tableId = (data['tableId'] as String?) ?? '';
        if (tableId.isEmpty) continue;
        final rr = (data['routesReady'] as Map<String, dynamic>?) ?? const {};
        final kReady = rr['kitchen'] == true;
        final bReady = rr['bar'] == true;
        final billable = status == 'ready';
        final entry = result.putIfAbsent(tableId, () => {'kitchen': false, 'bar': false, 'billable': false});
        entry['kitchen'] = entry['kitchen']! || kReady;
        entry['bar'] = entry['bar']! || bReady;
        entry['billable'] = entry['billable']! || billable;
      }
      return result;
    });
  }

  // Stream pending items for a route (kitchen/bar), grouped client-side
  Stream<List<Map<String, dynamic>>> streamPendingForRoute(String route) {
    return _db
        .collectionGroup('items')
        .where('route', isEqualTo: route)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              final ticketRef = d.reference.parent.parent!; // tickets/{id}
              final tableId = (data['tableId'] ?? '').toString();
              final menuItemId = (data['menuItemId'] ?? '').toString();
              final qty = (data['qty'] as num?)?.toInt() ?? 1;
              final status = (data['status'] ?? 'open').toString();
              final r = (data['route'] ?? '').toString();
              final name = (data['name'] ?? '').toString();
              final notes = (data['notes'] ?? '').toString();
              return {
                'ticketId': ticketRef.id,
                'tableId': tableId.isEmpty ? null : tableId,
                'menuItemId': menuItemId,
                'qty': qty,
                'status': status,
                'route': r,
                'itemId': d.id,
                'name': name,
                'notes': notes,
              };
            }).where((m) => m['status'] == 'open' || m['status'] == 'sentToKitchen').toList());
  }

  static TicketStatus _statusFromString(String s) {
    switch (s) {
      case 'open':
        return TicketStatus.open;
      case 'sentToKitchen':
        return TicketStatus.sentToKitchen;
      case 'ready':
        return TicketStatus.ready;
      case 'served':
        return TicketStatus.served;
      case 'paid':
        return TicketStatus.paid;
      default:
        return TicketStatus.open;
    }
  }

  // ADMIN/MAINT: delete all tickets (and their items). Use with caution.
  Future<void> deleteAllTickets({bool includePaid = true}) async {
    // First delete ALL items across collectionGroup to remove any orphans
    final itemsSnap = await _db.collectionGroup('items').get();
    for (final it in itemsSnap.docs) {
      try {
        await it.reference.delete();
      } catch (_) {/* ignore individual delete errors */}
    }

    // Then delete tickets themselves (optionally excluding paid)
    final q = includePaid
        ? await _db.collection('tickets').get()
        : await _db.collection('tickets').where('status', isNotEqualTo: 'paid').get();
    for (final doc in q.docs) {
      try {
        await doc.reference.delete();
      } catch (_) {/* ignore */}
    }
  }
}
