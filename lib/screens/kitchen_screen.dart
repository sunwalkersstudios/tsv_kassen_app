import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/entities.dart';
import '../repo/menu_repo.dart';
import '../state/tables_provider.dart';
import '../repo/tickets_repo.dart';
import '../state/events_provider.dart';

class KitchenScreen extends StatelessWidget {
  const KitchenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final menuRepo = MenuRepo();
    final tables = context.watch<TablesProvider>().tables;
    final ticketsRepo = TicketsRepo();

    return Scaffold(
      appBar: AppBar(title: const Text('Küche')),
      body: StreamBuilder(
        stream: ticketsRepo.streamPendingForRoute('kitchen'),
        builder: (context, tSnap) {
          if (tSnap.hasError) {
            return Center(child: Text('Fehler: ${tSnap.error}'));
          }
          final pending = tSnap.data ?? [];
          if (pending.isEmpty) {
            return const Center(child: Text('Keine offenen Bestellungen für die Küche'));
          }
          final activeEventId = context.watch<EventsProvider>().activeEvent?.id;
          return StreamBuilder(
            stream: menuRepo.streamForService(activeEventId: activeEventId),
            builder: (context, mSnap) {
              if (mSnap.hasError) {
                return Center(child: Text('Fehler im Menü: ${mSnap.error}'));
              }
              final menu = mSnap.data ?? const [];
              // Group by ticketId
              final byTicket = <String, List<Map<String, dynamic>>>{};
              for (final p in pending) {
                byTicket.putIfAbsent(p['ticketId'] as String, () => []).add(p);
              }
              return ListView(
                children: [
                  for (final entry in byTicket.entries)
                    Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FutureBuilder<String?>(
                          future: () async {
                            // Prefer denormalized tableName if available on ticket, else resolve by id
                            final name = await TicketsRepo().getTicketTableName(entry.key);
                            if (name != null && name.isNotEmpty) return name;
                            final first = entry.value.first;
                            final itemTableId = (first['tableId'] as String?) ?? '';
                            final effectiveId = itemTableId.isNotEmpty
                                ? itemTableId
                                : await TicketsRepo().getTicketTableId(entry.key) ?? '';
                            final tableName = tables.firstWhere(
                              (tb) => tb.id == effectiveId,
                              orElse: () => TableEntity(id: '', name: 'Unbekannt', row: 0, col: 0),
                            ).name;
                            return tableName;
                          }(),
                          builder: (context, tSnap) {
                            final tableName = (tSnap.data ?? 'Tisch unbekannt');
                            return Text(
                              tableName.isEmpty ? 'Tisch unbekannt' : tableName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        ...entry.value.map((p) {
                          final menuItemId = (p['menuItemId'] ?? '').toString();
                          final dnName = (p['name'] as String?)?.trim();
                          final qty = (p['qty'] as int?) ?? 1;
                          final status = (p['status'] ?? '').toString();
                          String? nameToShow = dnName?.isNotEmpty == true ? dnName : null;
                          if (nameToShow == null) {
                            final idx = menu.indexWhere((m) => m.id == menuItemId);
                            if (idx != -1) nameToShow = menu[idx].name;
                          }
                          nameToShow ??= 'Unbekannt ($menuItemId)';
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text('$nameToShow x$qty'),
                            subtitle: Text('Status: $status' + ((p['notes'] as String?)?.isNotEmpty == true ? ' • Hinweis: ${p['notes']}' : '')),
                          );
                        }),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: () => ticketsRepo.markRouteReady(entry.key, 'kitchen'),
                            child: const Text('Fertig'),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
