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
import '../util/money.dart';

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
      final selectedId = await showDialog<String>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text('Ticket auswählen – ${tableName.isNotEmpty ? tableName : widget.tableId}'),
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
                  child: StreamBuilder<List<MenuItemEntity>>(
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

                      final drinks = items.where((m) => m.category.toLowerCase() == 'getränke'.toLowerCase()).toList();
                      final food = items.where((m) => m.category.toLowerCase() == 'speisen'.toLowerCase()).toList();
                      final grill = items.where((m) => m.category.toLowerCase() == 'grillhütte'.toLowerCase()).toList();
                      final knownIds = {
                        ...drinks.map((e) => e.id),
                        ...food.map((e) => e.id),
                        ...grill.map((e) => e.id),
                      };
                      final rest = items.where((m) => !knownIds.contains(m.id)).toList();

                      Widget itemTile(MenuItemEntity m) {
                        return ListTile(
                          title: Text('${m.name} — ${Money.format(m.priceCents)}'),
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
                                    await ticketsRepo.addItem(
                                      ticketId: _ticketId!,
                                      tableId: widget.tableId,
                                      menuItemId: m.id,
                                      qty: 1,
                                      route: m.route,
                                      name: m.name,
                                      priceCents: m.priceCents,
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
                                  ticketsRepo.addItem(
                                    ticketId: _ticketId!,
                                    tableId: widget.tableId,
                                    menuItemId: m.id,
                                    qty: 1,
                                    route: m.route,
                                    name: m.name,
                                    priceCents: m.priceCents,
                                    category: m.category,
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      }

                      List<Widget> buildSection(String title, List<MenuItemEntity> list) {
                        if (list.isEmpty) return [];
                        return [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          ...list.map(itemTile),
                          const Divider(),
                        ];
                      }

                      return ListView(
                        children: [
                          ...buildSection('Getränke', drinks),
                          ...buildSection('Speisen', food),
                          ...buildSection('Grillhütte', grill),
                          ...buildSection('Sonstiges', rest),
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
                                final readyCount = tItems
                                    .where((i) => (i.status == TicketStatus.ready) && (i.route == 'kitchen' || i.route == 'bar'))
                                    .length;
                                final children = <Widget>[];
                                if (readyCount > 0) {
                                  children.add(
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: OutlinedButton.icon(
                                          icon: const Icon(Icons.done_all),
                                          label: Text('Alle serviert ($readyCount)'),
                                          onPressed: () async {
                                            await ticketsRepo.markAllReadyServed(_ticketId!);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Alle fertigen Artikel als serviert markiert.')),
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                children.addAll(tItems.map((i) {
                                    final idx = items.indexWhere((m) => m.id == i.menuItemId);
                                    if (idx == -1) {
                                      return ListTile(
                                        title: Text('Unbekanntes Item (${i.menuItemId}) x${i.qty}'),
                                        subtitle: Text('Status: ${i.status.name}${i.notes.isNotEmpty ? ' • Hinweis: ${i.notes}' : ''}'),
                                      );
                                    }
                                    final menuItem = items[idx];
                                    final isKitchenBar = menuItem.route == 'kitchen' || menuItem.route == 'bar';
                                    final isReady = i.status == TicketStatus.ready;
                                    final isServed = i.status == TicketStatus.served;
                                    final bool markRed = isKitchenBar && (i.status == TicketStatus.open || i.status == TicketStatus.sentToKitchen);
                                    final Color? tileColor = isKitchenBar
                                      ? (isReady
                                        ? Colors.green.shade50
                                        : (isServed
                                          ? Colors.blue.shade50
                                          : (markRed ? Colors.red.shade50 : null)))
                                      : null;
                                    final Color? titleColor = isKitchenBar
                                      ? (isReady
                                        ? Colors.green.shade800
                                        : (isServed
                                          ? Colors.blue.shade800
                                          : (markRed ? Colors.red.shade800 : null)))
                                      : null;
                                    return ListTile(
                                      tileColor: tileColor,
                                      title: Text('${menuItem.name} ×${i.qty} — ${Money.format(menuItem.priceCents * i.qty)}'),
                                      titleTextStyle: titleColor != null
                                          ? Theme.of(context).textTheme.titleMedium?.copyWith(color: titleColor)
                                          : Theme.of(context).textTheme.titleMedium,
                                      subtitle: Text('${menuItem.category} • Route: ${menuItem.route} • Status: ${i.status.name}${i.notes.isNotEmpty ? ' • Hinweis: ${i.notes}' : ''}'),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (i.status == TicketStatus.open)
                                            IconButton(
                                              icon: const Icon(Icons.remove_circle_outline),
                                              tooltip: i.qty > 1
                                                  ? 'Eine weniger'
                                                  : 'Position entfernen',
                                              onPressed: () async {
                                                await ticketsRepo.changeItemQty(
                                                  ticketId: _ticketId!,
                                                  itemId: i.id,
                                                  delta: -1,
                                                );
                                              },
                                            ),
                                          if (i.status == TicketStatus.open && i.qty > 1)
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline),
                                              tooltip: 'Ganze Position entfernen',
                                              onPressed: () async {
                                                await ticketsRepo.deleteItem(ticketId: _ticketId!, itemId: i.id);
                                              },
                                            ),
                                          if (isKitchenBar && i.status == TicketStatus.ready)
                                            IconButton(
                                              icon: const Icon(Icons.done_all),
                                              tooltip: 'Als serviert markieren',
                                              onPressed: () async {
                                                await ticketsRepo.markItemServed(_ticketId!, i.id);
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('${menuItem.name} serviert markiert')),
                                                  );
                                                }
                                              },
                                            ),
                                        ],
                                      ),
                                    );
                                  }).toList());
                                return Column(children: children);
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
                                    // Berechne Beträge für das Popup - nur servierte Items
                                    final raw = await ticketsRepo.getItemsRaw(_ticketId!);
                                    final servedUnpaidItems = raw.where((m) {
                                      final status = (m['status'] ?? 'open').toString();
                                      // Nur servierte Items (routed/ready/billable), keine offenen oder bezahlten
                                      return status != 'paid' && status != 'open';
                                    }).toList();
                                    
                                    int totalUnpaidCents = 0;
                                    for (final m in servedUnpaidItems) {
                                      totalUnpaidCents += Money.itemLineTotal(m);
                                    }

                                    // Ganzzahlig halbieren: ein ungerader Cent
                                    // faellt der ersten Haelfte zu, statt in
                                    // Fliesskomma zu verschwinden.
                                    final halfAmountCents = (totalUnpaidCents + 1) ~/ 2;
                                    
                                    if (!mounted) return;
                                    // this.context: der State-eigene Context gehoert zum
                                    // mounted-Check oben, das aeussere `context` nicht.
                                    String? mode = await showModalBottomSheet<String>(
                                      context: this.context,
                                      builder: (ctx) => SafeArea(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Text(
                                                'Zahlungsoptionen',
                                                style: Theme.of(context).textTheme.titleLarge,
                                              ),
                                            ),
                                            ListTile(
                                              leading: const Icon(Icons.payments),
                                              title: const Text('Gesamtrechnung'),
                                              subtitle: Text(Money.format(totalUnpaidCents)),
                                              trailing: const Icon(Icons.arrow_forward),
                                              onTap: () => Navigator.of(ctx).pop('full'),
                                            ),
                                            ListTile(
                                              leading: const Icon(Icons.call_split),
                                              title: const Text('Rechnung halbieren (50/50)'),
                                              subtitle: Text('${Money.format(halfAmountCents)} pro Person'),
                                              trailing: const Icon(Icons.arrow_forward),
                                              onTap: () => Navigator.of(ctx).pop('half'),
                                            ),
                                            ListTile(
                                              leading: const Icon(Icons.checklist),
                                              title: const Text('Teilrechnung (Artikel auswählen)'),
                                              subtitle: const Text('Betrag nach Auswahl'),
                                              trailing: const Icon(Icons.arrow_forward),
                                              onTap: () => Navigator.of(ctx).pop('select'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                    if (!mounted || mode == null) return;

                                    String? saleId;
                                    if (mode == 'full') {
                                      try {
                                        saleId = await ticketsRepo.markTicketPaid(_ticketId!);
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Nur servierte Artikel können bezahlt werden.')), 
                                          );
                                        }
                                        return;
                                      }
                                    } else if (mode == 'half') {
                                      final raw = await ticketsRepo.getItemsRaw(_ticketId!);
                                      final served = raw.where((m) => (m['status'] ?? 'open') == 'served').toList();
                                      if (served.isEmpty) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Keine servierten Artikel für 50/50 vorhanden.')), 
                                          );
                                        }
                                        return;
                                      }
                                      final itemsWithTotal = served.map((m) => {
                                        ...m,
                                        'lineTotalCents': Money.itemLineTotal(m),
                                      }).toList()
                                        ..sort((a, b) => (b['lineTotalCents'] as int).compareTo(a['lineTotalCents'] as int));
                                      final totalCents = itemsWithTotal.fold<int>(0, (p, m) => p + (m['lineTotalCents'] as int));
                                      final targetCents = totalCents ~/ 2;
                                      int accCents = 0;
                                      final selectedIds = <String>[];
                                      for (final m in itemsWithTotal) {
                                        if (accCents >= targetCents) break;
                                        selectedIds.add(m['id'] as String);
                                        accCents += (m['lineTotalCents'] as int);
                                      }
                                      if (selectedIds.isEmpty) {
                                        selectedIds.add(itemsWithTotal.first['id'] as String);
                                      }
                                      try {
                                        saleId = await ticketsRepo.paySelectedItems(_ticketId!, selectedIds);
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Nur servierte Artikel können bezahlt werden.')), 
                                          );
                                        }
                                        return;
                                      }
                                    }
                                    if (mode == 'select') {
                                      final raw = await ticketsRepo.getItemsRaw(_ticketId!);
                                      final selectable = raw.where((m) => (m['status'] ?? 'open') != 'paid').toList();
                                      final selected = <String>{};
                                      int selTotalCents = 0;
                                      int computeTotal() {
                                        int t = 0;
                                        for (final m in selectable) {
                                          if (!selected.contains(m['id'] as String)) continue;
                                          t += Money.itemLineTotal(m);
                                        }
                                        return t;
                                      }
                                      if (!context.mounted) return;
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
                                                              final notes = (m['notes'] ?? '').toString();
                                                              final st = (m['status'] ?? 'open').toString();
                                                              final lineCents = Money.itemLineTotal(m);
                                                              return CheckboxListTile(
                                                                value: selected.contains(id),
                                                                onChanged: st == 'served'
                                                                    ? (v) {
                                                                        setStateDlg(() {
                                                                          if (v == true) {
                                                                            selected.add(id);
                                                                          } else {
                                                                            selected.remove(id);
                                                                          }
                                                                          selTotalCents = computeTotal();
                                                                        });
                                                                      }
                                                                    : null,
                                                                title: Text('$name ×$qty — ${Money.format(lineCents)}'),
                                                                subtitle: Text([
                                                                  if (notes.isNotEmpty) notes,
                                                                  if (st != 'served') 'Noch nicht serviert',
                                                                ].join(' • ')),
                                                              );
                                                            }),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Align(
                                                      alignment: Alignment.centerRight,
                                                      child: Text('Auswahl-Summe: ${Money.format(selTotalCents)}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                                        try {
                                          saleId = await ticketsRepo.paySelectedItems(_ticketId!, selected.toList());
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Nur servierte Artikel können bezahlt werden.')), 
                                            );
                                          }
                                          return;
                                        }
                                      } else {
                                        return;
                                      }
                                    }
                                    if (!context.mounted) return;
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
