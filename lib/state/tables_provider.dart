import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/entities.dart';
import '../repo/tables_repo.dart';

class TablesProvider extends ChangeNotifier {
  final List<TableEntity> _tables = [];
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  int gridRows = 3;
  int gridCols = 4;

  TablesProvider({bool subscribe = true}) {
    if (subscribe) {
      // Subscribe to Firestore tables so IDs remain stable across sessions
      final repo = TablesRepo();
      _sub = repo.streamAll().listen((list) {
        _tables
          ..clear()
          ..addAll(list.map((m) => TableEntity(
                id: (m['id'] as String),
                name: (m['name'] as String? ?? ''),
                row: (m['row'] as int? ?? 0),
                col: (m['col'] as int? ?? 0),
                active: (m['active'] as bool? ?? true),
              )));
        notifyListeners();
      });
    }
  }

  List<TableEntity> get tables => List.unmodifiable(_tables);

  // Test helper: seed tables without Firestore subscription
  void seedTestTables(List<TableEntity> list) {
    _tables
      ..clear()
      ..addAll(list);
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    super.dispose();
  }
}
