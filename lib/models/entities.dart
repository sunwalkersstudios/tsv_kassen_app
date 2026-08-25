enum UserRole { server, kitchen, bar, admin }

enum TicketStatus { open, sentToKitchen, ready, served, paid }

class TableEntity {
  final String id;
  String name;
  int row;
  int col;
  bool active;
  TableEntity({
    required this.id,
    required this.name,
    required this.row,
    required this.col,
    this.active = true,
  });
}

class MenuItemEntity {
  final String id;
  String name;

  /// Preis in ganzzahligen Cent. Fliesskomma waere hier die falsche Grundlage:
  /// die Fehler summieren sich ueber die Positionen eines Belegs auf.
  int priceCents;

  String category; // Speisen / Getraenke / ...
  String route; // kitchen/bar
  String? eventId; // null => Basiskarte, sonst veranstaltungsbezogen

  /// Angepinnt: erscheint in der Bestellmaske ganz vorn unter "Favoriten".
  /// Gedacht fuer die Handvoll Artikel, die den Grossteil ausmachen - im alten
  /// Datenbestand waren Schnitzel und Bier zusammen 111 von 493 Positionen.
  bool favorite;

  MenuItemEntity({
    required this.id,
    required this.name,
    required this.priceCents,
    required this.category,
    required this.route,
    this.eventId,
    this.favorite = false,
  });
}

class TicketItemEntity {
  final String id;
  final String menuItemId;
  int qty;
  String notes;
  String route; // kitchen/bar
  TicketStatus status;
  TicketItemEntity({
    required this.id,
    required this.menuItemId,
    required this.qty,
    this.notes = '',
    required this.route,
    this.status = TicketStatus.open,
  });
}

class TicketEntity {
  final String id;
  final String tableId;
  TicketStatus status;
  final String serverId;
  final DateTime createdAt;
  final List<TicketItemEntity> items;
  TicketEntity({
    required this.id,
    required this.tableId,
    required this.status,
    required this.serverId,
    required this.createdAt,
    required this.items,
  });
}

class UserProfile {
  final String uid;
  final String displayName;
  final UserRole role;
  UserProfile({required this.uid, required this.displayName, required this.role});
}

class EventEntity {
  final String id;
  String name;
  bool active;
  DateTime? startAt;
  DateTime? endAt;
  EventEntity({
    required this.id,
    required this.name,
    this.active = false,
    this.startAt,
    this.endAt,
  });
}
