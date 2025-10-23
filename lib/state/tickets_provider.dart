import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/entities.dart';

class TicketsProvider extends ChangeNotifier {
  final _uuid = const Uuid();
  final List<TicketEntity> _tickets = [];

  List<TicketEntity> get tickets => List.unmodifiable(_tickets);

  TicketEntity openTicketForTable(String tableId, String serverId) {
    final existing = _tickets.where((t) => t.tableId == tableId && t.status != TicketStatus.paid);
    if (existing.isNotEmpty) return existing.first;
    final t = TicketEntity(
      id: _uuid.v4(),
      tableId: tableId,
      status: TicketStatus.open,
      serverId: serverId,
      createdAt: DateTime.now(),
      items: [],
    );
    _tickets.add(t);
    notifyListeners();
    return t;
  }

  void addItem({
    required String ticketId,
    required String menuItemId,
    required int qty,
    required String route,
    String notes = '',
  }) {
    final idx = _tickets.indexWhere((t) => t.id == ticketId);
    if (idx == -1) return;
    final t = _tickets[idx];
    final items = List<TicketItemEntity>.from(t.items)
      ..add(TicketItemEntity(id: _uuid.v4(), menuItemId: menuItemId, qty: qty, notes: notes, route: route, status: TicketStatus.open));
    _tickets[idx] = TicketEntity(
      id: t.id,
      tableId: t.tableId,
      status: t.status, // remain in current state until explicitly sent
      serverId: t.serverId,
      createdAt: t.createdAt,
      items: items,
    );
    notifyListeners();
  }

  // Mark all open items as sent to kitchen/bar (based on their route)
  void sendTicket(String ticketId) {
    final idx = _tickets.indexWhere((t) => t.id == ticketId);
    if (idx == -1) return;
    final t = _tickets[idx];
    final items = t.items
        .map((i) => i.status == TicketStatus.open
            ? TicketItemEntity(id: i.id, menuItemId: i.menuItemId, qty: i.qty, notes: i.notes, route: i.route, status: TicketStatus.sentToKitchen)
            : i)
        .toList();
    _tickets[idx] = TicketEntity(
      id: t.id,
      tableId: t.tableId,
      status: TicketStatus.sentToKitchen,
      serverId: t.serverId,
      createdAt: t.createdAt,
      items: items,
    );
    notifyListeners();
  }

  // Kitchen/Bar marks all items for a route as ready, then ticket becomes ready if everything ready
  void markRouteReady(String ticketId, String route) {
    final idx = _tickets.indexWhere((t) => t.id == ticketId);
    if (idx == -1) return;
    final t = _tickets[idx];
    final items = t.items
        .map((i) => i.route == route && i.status != TicketStatus.ready
            ? TicketItemEntity(id: i.id, menuItemId: i.menuItemId, qty: i.qty, notes: i.notes, route: i.route, status: TicketStatus.ready)
            : i)
        .toList();
    final allReady = items.every((i) => i.status == TicketStatus.ready);
    _tickets[idx] = TicketEntity(
      id: t.id,
      tableId: t.tableId,
      status: allReady ? TicketStatus.ready : t.status,
      serverId: t.serverId,
      createdAt: t.createdAt,
      items: items,
    );
    notifyListeners();
  }

  void updateItemStatus(String ticketId, String itemId, TicketStatus status) {
    final idx = _tickets.indexWhere((t) => t.id == ticketId);
    if (idx == -1) return;
    final t = _tickets[idx];
    final items = t.items.map((i) => i.id == itemId ? TicketItemEntity(id: i.id, menuItemId: i.menuItemId, qty: i.qty, notes: i.notes, route: i.route, status: status) : i).toList();
    // If all items ready -> ticket ready
    final newStatus = items.any((i) => i.status == TicketStatus.open || i.status == TicketStatus.sentToKitchen)
        ? t.status
        : TicketStatus.ready;
    _tickets[idx] = TicketEntity(
      id: t.id,
      tableId: t.tableId,
      status: newStatus,
      serverId: t.serverId,
      createdAt: t.createdAt,
      items: items,
    );
    notifyListeners();
  }

  void markTicketServed(String ticketId) {
    final idx = _tickets.indexWhere((t) => t.id == ticketId);
    if (idx == -1) return;
    final t = _tickets[idx];
    _tickets[idx] = TicketEntity(
      id: t.id,
      tableId: t.tableId,
      status: TicketStatus.served,
      serverId: t.serverId,
      createdAt: t.createdAt,
      items: t.items,
    );
    notifyListeners();
  }

  void markTicketPaid(String ticketId) {
    final idx = _tickets.indexWhere((t) => t.id == ticketId);
    if (idx == -1) return;
    final t = _tickets[idx];
    _tickets[idx] = TicketEntity(
      id: t.id,
      tableId: t.tableId,
      status: TicketStatus.paid,
      serverId: t.serverId,
      createdAt: t.createdAt,
      items: t.items,
    );
    notifyListeners();
  }
}
