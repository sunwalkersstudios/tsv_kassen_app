import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/entities.dart';

class MenuProvider extends ChangeNotifier {
  final _uuid = const Uuid();
  final List<MenuItemEntity> _items = [];

  List<MenuItemEntity> get items => List.unmodifiable(_items);

  void seedDefaults() {
    if (_items.isNotEmpty) return;
    _items.addAll([
      MenuItemEntity(id: _uuid.v4(), name: 'Schnitzel', price: 12.5, category: 'Speisen', route: 'kitchen'),
      MenuItemEntity(id: _uuid.v4(), name: 'Pommes', price: 3.5, category: 'Speisen', route: 'kitchen'),
      MenuItemEntity(id: _uuid.v4(), name: 'Cola', price: 2.8, category: 'Getränke', route: 'bar'),
      MenuItemEntity(id: _uuid.v4(), name: 'Weizen', price: 3.8, category: 'Getränke', route: 'bar'),
    ]);
    notifyListeners();
  }

  void addItem(MenuItemEntity item) {
    _items.add(item);
    notifyListeners();
  }

  void removeItem(String id) {
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
  }
}
