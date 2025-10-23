import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../state/auth_provider.dart';
import '../state/events_provider.dart';
import '../repo/menu_repo.dart';
import '../repo/tickets_repo.dart';
import '../state/tables_provider.dart';
import '../models/entities.dart';
import '../util/receipt_service.dart';

class OrderScreen extends StatefulWidget {
  final String tableId;
  const OrderScreen({super.key, required this.tableId});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  String? _ticketId;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Open or get ticket once, outside of build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initTicketSelection();
    });
  }

  Future<void> _initTicketSelection() async {
    try {
      final auth = context.read<AuthProvider>();
      final tables = context.read<TablesProvider>().tables;
      final tableName = tables.firstWhere(
        (t) => t.id == widget.tableId,
        orElse: () => TableEntity(id: widget.tableId, name: widget.tableId, row: 0, col: 0),
      ).name;
      final repo = TicketsRepo();
      // Fetch all unpaid tickets from server for this table (avoid cache)
      final existing = await repo.fetchUnpaidTicketsForTable(widget.tableId);
      if (!mounted) return;
      if (existing.isEmpty) {
        final id = await repo.createTicket(tableId: widget.tableId, serverId: auth.user!.uid, tableName: tableName);
        if (!mounted) return;
        setState(() => _ticketId = id);
        return;
      }
      if (existing.length == 1) {
        setState(() => _ticketId = existing.first['id'] as String);
        return;
      }
      // Multiple unpaid tickets -> let user choose
      final selectedId = await showDialog<String>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text('Ticket auswählen – ${tableName.isNotEmpty ? tableName : widget.tableId}') ,
            content: SizedBox(
              width: 420,
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final t in existing)
                    ListTile(
                      leading: const Icon(Icons.receipt_long),
                      title: Text('Ticket ${t['id']}'),
                      subtitle: Text(_formatTicketMeta(t)),
                      onTap: () => Navigator.of(ctx).pop(t['id'] as String),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Abbrechen')),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(ctx).pop('NEW'),
                icon: const Icon(Icons.add),
                label: const Text('Neues Ticket'),
              ),
            ],
          );
        },
      );
      if (!mounted) return;
      if (selectedId == null) {
        // User aborted selection; keep screen idle with message
        setState(() => _error = 'Auswahl abgebrochen');
        return;
      }
      if (selectedId == 'NEW') {
        final id = await repo.createTicket(tableId: widget.tableId, serverId: auth.user!.uid, tableName: tableName);
        if (!mounted) return;
        setState(() => _ticketId = id);
      } else {
        setState(() => _ticketId = selectedId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler beim Laden der Tickets: $e')));
    }
  }

  String _formatTicketMeta(Map<String, dynamic> t) {
    try {
      final status = (t['status'] ?? 'open').toString();
      final ta = (t['updatedAt'] as Timestamp?) ?? (t['createdAt'] as Timestamp?);
      final dt = ta?.toDate();
      final when = dt != null ? '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}' : '';
      return 'Status: $status${when.isNotEmpty ? ' • $when' : ''}';
    } catch (_) {
      return (t['status'] ?? 'open').toString();
    }
  }

  @override
  Widget build(BuildContext context) {
  final events = context.watch<EventsProvider>();
  final activeEventId = events.activeEvent?.id;
  final menuStream = MenuRepo().streamForService(activeEventId: activeEventId);
  final ticketsRepo = TicketsRepo();

    return Scaffold(
      appBar: AppBar(title: const Text('Bestellung')),
    body: _ticketId == null
      ? (_error != null
        ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Fehler: $_error')))
        : const Center(child: CircularProgressIndicator()))
          : Column(
              children: [
                Expanded(
                  child: StreamBuilder(
                    stream: menuStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Fehler beim Laden des Menüs: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final items = snapshot.data!;
                      if (items.isEmpty) {
                        return const Center(child: Text('Keine Menüartikel gefunden'));
                      }
                      return ListView(
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('Artikel', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          ...items.map((m) => ListTile(
                                title: Text('${m.name} - €${m.price.toStringAsFixed(2)}'),
                                subtitle: Text('${m.category} • Route: ${m.route}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.note_add_outlined),
                                      tooltip: 'Extrawunsch hinzufügen',
                                      onPressed: () async {
                                        if (_ticketId == null) return;
                                        final notesCtrl = TextEditingController();
                                        final add = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: Text('Extrawunsch zu ${m.name}'),
                                            content: TextField(
                                              controller: notesCtrl,
                                              decoration: const InputDecoration(hintText: 'z. B. ohne Eis, extra Ketchup'),
                                            ),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
                                              ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Hinzufügen')),
                                            ],
                                          ),
                                        );
                                        if (add == true) {
                                          final derivedRoute = m.category == 'Getränke' ? 'bar' : 'kitchen';
                                          await ticketsRepo.addItem(
                                            ticketId: _ticketId!,
                                            tableId: widget.tableId,
                                            menuItemId: m.id,
                                            qty: 1,
                                            route: derivedRoute,
                                            name: m.name,
                                            price: m.price,
                                            category: m.category,
                                            notes: notesCtrl.text.trim(),
                                          );
                                        }
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add),
                                      onPressed: () {
                                        if (_ticketId == null) return;
                                        final derivedRoute = m.category == 'Getränke' ? 'bar' : 'kitchen';
                                        ticketsRepo.addItem(
                                          ticketId: _ticketId!,
                                          tableId: widget.tableId,
                                          menuItemId: m.id,
                                          qty: 1,
                                          route: derivedRoute,
                                          name: m.name,
                                          price: m.price,
                                          category: m.category,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              )),
                          const Divider(),
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('Ticket-Positionen', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          if (_ticketId != null)
                            StreamBuilder(
                              stream: ticketsRepo.streamTicketItems(_ticketId!),
                              builder: (context, tSnap) {
                                if (tSnap.hasError) {
                                  return Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text('Fehler beim Laden des Tickets: ${tSnap.error}'),
                                  );
                                }
                                if (!tSnap.hasData) return const SizedBox.shrink();
                                final tItems = tSnap.data!;
                                if (tItems.isEmpty) {
                                  return const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text('Noch keine Positionen'),
                                  );
                                }
                                return Column(
                                  children: tItems.map((i) {
                                    final idx = items.indexWhere((m) => m.id == i.menuItemId);
                                    if (idx == -1) {
                                      return ListTile(
                                        title: Text('Unbekanntes Item (${i.menuItemId}) x${i.qty}'),
                                        subtitle: Text('Status: ${i.status.name}${i.notes.isNotEmpty ? ' • Hinweis: ${i.notes}' : ''}'),
                                      );
                                    }
                                    final menuItem = items[idx];
                                    return ListTile(
                                      title: Text('${menuItem.name} x${i.qty} - €${(menuItem.price * i.qty).toStringAsFixed(2)}'),
                                      subtitle: Text('${menuItem.category} • Route: ${menuItem.route} • Status: ${i.status.name}${i.notes.isNotEmpty ? ' • Hinweis: ${i.notes}' : ''}'),
                                      trailing: i.status == TicketStatus.open
                                          ? IconButton(
                                              icon: const Icon(Icons.delete_outline),
                                              tooltip: 'Position entfernen',
                                              onPressed: () async {
                                                await ticketsRepo.deleteItem(ticketId: _ticketId!, itemId: i.id);
                                              },
                                            )
                                          : null,
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                        ],
                      );
                    },
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _ticketId == null
                                ? null
                                : () async {
                                    // We can't easily count open items without another stream; just send and show generic feedback
                                    await ticketsRepo.sendTicket(_ticketId!);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('An Küche/Bar gesendet')),
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.send),
                            label: const Text('An Küche/Bar senden'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _ticketId == null
                                ? null
                                : () async {
                                    // Choose pay mode: full, split half, or select items
                                    String? mode = await showModalBottomSheet<String>(
                                      context: context,
                                      builder: (ctx) => SafeArea(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ListTile(
                                              leading: const Icon(Icons.payments),
                                              title: const Text('Gesamtes Ticket bezahlen'),
                                              onTap: () => Navigator.of(ctx).pop('full'),
                                            ),
                                            ListTile(
                                              leading: const Icon(Icons.call_split),
                                              title: const Text('Rechnung halbieren (50/50)'),
                                              onTap: () => Navigator.of(ctx).pop('half'),
                                            ),
                                            ListTile(
                                              leading: const Icon(Icons.checklist),
                                              title: const Text('Einzelne Artikel auswählen'),
                                              onTap: () => Navigator.of(ctx).pop('select'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                    if (!mounted || mode == null) return;

                                    String? saleId;
                                    if (mode == 'full') {
                                      saleId = await ticketsRepo.markTicketPaid(_ticketId!);
                                    } else if (mode == 'half') {
                                      // 50/50: Greedy selection of items to approximate half of total
                                      final raw = await ticketsRepo.getItemsRaw(_ticketId!);
                                      final unpaid = raw.where((m) => (m['status'] ?? 'open') != 'paid').toList();
                                      if (unpaid.isEmpty) return;
                                      // Compute totals per item (qty * price), sort desc
                                      final itemsWithTotal = unpaid.map((m) {
                                        final qty = (m['qty'] as num?)?.toInt() ?? 1;
                                        final price = (m['price'] as num?)?.toDouble() ?? 0.0;
                                        return {
                                          ...m,
                                          'lineTotal': qty * price,
                                        };
                                      }).toList()
                                        ..sort((a, b) => (b['lineTotal'] as double).compareTo(a['lineTotal'] as double));
                                      final total = itemsWithTotal.fold<double>(0.0, (p, m) => p + (m['lineTotal'] as double));
                                      final target = total / 2.0;
                                      double acc = 0.0;
                                      final selectedIds = <String>[];
                                      for (final m in itemsWithTotal) {
                                        if (acc >= target) break;
                                        selectedIds.add(m['id'] as String);
                                        acc += (m['lineTotal'] as double);
                                      }
                                      if (selectedIds.isEmpty) {
                                        // Fallback: select the first item
                                        selectedIds.add(itemsWithTotal.first['id'] as String);
                                      }
                                      saleId = await ticketsRepo.paySelectedItems(_ticketId!, selectedIds);
                                    }
                                    if (mode == 'select') {
                                      // Build selection UI from raw items to access prices
                                      final raw = await ticketsRepo.getItemsRaw(_ticketId!);
                                      final selectable = raw.where((m) => (m['status'] ?? 'open') != 'paid').toList();
                                      final selected = <String>{};
                                      double selTotal = 0.0;
                                      double computeTotal() {
                                        double t = 0.0;
                                        for (final m in selectable) {
                                          if (!selected.contains(m['id'] as String)) continue;
                                          final qty = (m['qty'] as num?)?.toInt() ?? 1;
                                          final price = (m['price'] as num?)?.toDouble() ?? 0.0;
                                          t += qty * price;
                                        }
                                        return t;
                                      }
                                      if (!mounted) return;
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) {
                                          return StatefulBuilder(builder: (ctx, setStateDlg) {
                                            return AlertDialog(
                                              title: const Text('Artikel auswählen'),
                                              content: SizedBox(
                                                width: 400,
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Flexible(
                                                      child: ListView(
                                                        shrinkWrap: true,
                                                        children: [
                                                          for (final m in selectable)
                                                            Builder(builder: (context) {
                                                              final id = (m['id'] as String);
                                                              final name = (m['name'] ?? m['menuItemId']).toString();
                                                              final qty = (m['qty'] as num?)?.toInt() ?? 1;
                                                              final price = (m['price'] as num?)?.toDouble() ?? 0.0;
                                                              final notes = (m['notes'] ?? '').toString();
                                                              final line = qty * price;
                                                              return CheckboxListTile(
                                                                value: selected.contains(id),
                                                                onChanged: (v) {
                                                                  setStateDlg(() {
                                                                    if (v == true) {
                                                                      selected.add(id);
                                                                    } else {
                                                                      selected.remove(id);
                                                                    }
                                                                    selTotal = computeTotal();
                                                                  });
                                                                },
                                                                title: Text('$name x$qty — €${line.toStringAsFixed(2)}'),
                                                                subtitle: notes.isNotEmpty ? Text(notes) : null,
                                                              );
                                                            }),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Align(
                                                      alignment: Alignment.centerRight,
                                                      child: Text('Auswahl-Summe: €${selTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
                                                ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Bezahlen')),
                                              ],
                                            );
                                          });
                                        },
                                      );
                                      if (confirmed == true && selected.isNotEmpty) {
                                        saleId = await ticketsRepo.paySelectedItems(_ticketId!, selected.toList());
                                      } else {
                                        return;
                                      }
                                    }

                                    if (!mounted) return;
                                    final choice = await showModalBottomSheet<String>(
                                      context: context,
                                      builder: (ctx) => SafeArea(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ListTile(
                                              leading: const Icon(Icons.receipt_long),
                                              title: const Text('Bon drucken (Kellner)'),
                                              onTap: () => Navigator.of(ctx).pop('bon'),
                                            ),
                                            ListTile(
                                              leading: const Icon(Icons.description),
                                              title: const Text('Bewirtungsbeleg drucken (Kasse)'),
                                              onTap: () => Navigator.of(ctx).pop('bewirtung'),
                                            ),
                                            ListTile(
                                              leading: const Icon(Icons.close),
                                              title: const Text('Abbrechen'),
                                              onTap: () => Navigator.of(ctx).pop(null),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                    try {
                                      if (saleId != null && choice == 'bon') {
                                        final receipt = ReceiptService();
                                        await receipt.printSale(saleId);
                                      } else if (saleId != null && choice == 'bewirtung') {
                                        // Print a blank hospitality receipt with placeholders for guest to fill
                                        final receipt = ReceiptService();
                                        await receipt.printHospitalityReceipt(saleId);
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Druck fehlgeschlagen: $e')),
                                        );
                                      }
                                    }
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Bezahlung erfasst')),
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.payments),
                            label: const Text('Bezahlen'),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
    );
  }
}
