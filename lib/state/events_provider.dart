import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/entities.dart';

class EventsProvider extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  List<EventEntity> _events = [];
  EventEntity? _active;

  List<EventEntity> get events => List.unmodifiable(_events);
  EventEntity? get activeEvent => _active;

  void start() {
    _sub?.cancel();
    _sub = _db
        .collection('events')
        .orderBy('name')
        .snapshots()
        .listen((snap) {
      _events = snap.docs.map((d) {
        final data = d.data();
        return EventEntity(
          id: d.id,
          name: (data['name'] as String?) ?? d.id,
          active: (data['active'] as bool?) ?? false,
          startAt: (data['startAt'] as Timestamp?)?.toDate(),
          endAt: (data['endAt'] as Timestamp?)?.toDate(),
        );
      }).toList();
      _active = _events.firstWhere((e) => e.active, orElse: () => EventEntity(id: '', name: '', active: false));
      if (_active?.id.isEmpty == true) {
        _active = null;
      }
      notifyListeners();
    });
  }

  Future<void> addEvent({required String name, DateTime? startAt, DateTime? endAt}) async {
    await _db.collection('events').add({
      'name': name,
      'active': false,
      'startAt': startAt == null ? null : Timestamp.fromDate(startAt),
      'endAt': endAt == null ? null : Timestamp.fromDate(endAt),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setActive(String eventId, bool active) async {
    final batch = _db.batch();
    // Deactivate all if we are activating one
    if (active) {
      final all = await _db.collection('events').get();
      for (final doc in all.docs) {
        batch.update(doc.reference, {'active': doc.id == eventId});
      }
    } else {
      batch.update(_db.collection('events').doc(eventId), {'active': false});
    }
    await batch.commit();
  }

  Future<void> updateEvent(EventEntity e) async {
    await _db.collection('events').doc(e.id).set({
      'name': e.name,
      'startAt': e.startAt == null ? null : Timestamp.fromDate(e.startAt!),
      'endAt': e.endAt == null ? null : Timestamp.fromDate(e.endAt!),
    }, SetOptions(merge: true));
  }

  Future<void> deleteEvent(String id) async {
    await _db.collection('events').doc(id).delete();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
