import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/entities.dart';
import '../repo/menu_repo.dart';
import '../repo/tickets_repo.dart';
import '../state/auth_provider.dart';
import '../state/events_provider.dart';
import '../state/tables_provider.dart';
import '../util/money.dart';
import '../util/receipt_service.dart';
import '../widgets/order_menu_grid.dart';
import '../widgets/order_ticket_panel.dart';

/// Bestellmaske eines Tisches.
///
/// Vorher lagen Speisekarte und Ticketpositionen in einer einzigen Liste
/// untereinander: um zu sehen, was auf dem Ticket steht, musste man an der
/// gesamten Karte vorbeiscrollen. Jetzt stehen sie nebeneinander, die Summe
/// ist immer sichtbar.
///
/// Der Zahlweg - Gesamtrechnung, Halbierung, Teilrechnung, Belegdruck - lag
/// als rund 250 Zeilen lange Closure im onPressed einer Schaltflaeche. Er ist
/// unveraendert nach [_bezahlen] gewandert; an der Logik wurde nichts gedreht.
class OrderScreen extends StatefulWidget {
  final String tableId;
  const OrderScreen({super.key, required this.tableId});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final _ticketsRepo = TicketsRepo();

  String? _ticketId;
  String? _error;

  /// Gewaehlte Kategorie oder null fuer alle.
  String? _kategorie;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initTicketSelection();
    });
  }

  String get _tischName {
    final tables = context.read<TablesProvider>().tables;
    return tables
        .firstWhere(
          (t) => t.id == widget.tableId,
          orElse: () => TableEntity(id: widget.tableId, name: widget.tableId, row: 0, col: 0),
        )
        .name;
  }

  Future<void> _initTicketSelection() async {
    try {
      final auth = context.read<AuthProvider>();
      final tableName = _tischName;
      final repo = _ticketsRepo;
      final existing = await repo.fetchUnpaidTicketsForTable(widget.tableId);
      if (!mounted) return;
      if (existing.isEmpty) {
        final id = await repo.createTicket(
            tableId: widget.tableId, serverId: auth.user!.uid, tableName: tableName);
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
        builder: (ctx) => AlertDialog(
          title: Text('Offene Tickets – $tableName'),
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
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Abbrechen')),
            FilledButton.icon(
              onPressed: () => Navigator.of(ctx).pop('NEW'),
              icon: const Icon(Icons.add),
              label: const Text('Neues Ticket'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (selectedId == null) {
        setState(() => _error = 'Auswahl abgebrochen');
        return;
      }
      if (selectedId == 'NEW') {
        final id = await repo.createTicket(
            tableId: widget.tableId, serverId: auth.user!.uid, tableName: tableName);
        if (!mounted) return;
        setState(() => _ticketId = id);
      } else {
        setState(() => _ticketId = selectedId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Tickets konnten nicht geladen werden: $e')));
    }
  }

  String _formatTicketMeta(Map<String, dynamic> t) {
    try {
      final status = (t['status'] ?? 'open').toString();
      final ta = (t['updatedAt'] as Timestamp?) ?? (t['createdAt'] as Timestamp?);
      final dt = ta?.toDate();
      final when = dt != null
          ? '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
          : '';
      return 'Status: $status${when.isNotEmpty ? ' • $when' : ''}';
    } catch (_) {
      return (t['status'] ?? 'open').toString();
    }
  }

  // ------------------------------------------------------------- Bestellen

  Future<void> _hinzufuegen(MenuItemEntity m, {String notes = ''}) async {
    if (_ticketId == null) return;
    await _ticketsRepo.addItem(
      ticketId: _ticketId!,
      tableId: widget.tableId,
      menuItemId: m.id,
      qty: 1,
      route: m.route,
      name: m.name,
      priceCents: m.priceCents,
      category: m.category,
      notes: notes,
    );
  }

  Future<void> _extrawunsch(MenuItemEntity m) async {
    if (_ticketId == null) return;
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Extrawunsch zu ${m.name}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'z. B. ohne Zwiebeln, extra Ketchup'),
          onSubmitted: (_) => Navigator.of(ctx).pop(true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Hinzufügen')),
        ],
      ),
    );
    final text = ctrl.text.trim();
    ctrl.dispose();
    if (ok == true) await _hinzufuegen(m, notes: text);
  }

  Future<void> _senden() async {
    if (_ticketId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _ticketsRepo.sendTicket(_ticketId!);
      messenger.showSnackBar(const SnackBar(content: Text('An Küche und Bar gesendet')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Senden fehlgeschlagen: $e')));
    }
  }

  Future<void> _alleServiert() async {
    if (_ticketId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    await _ticketsRepo.markAllReadyServed(_ticketId!);
    if (!mounted) return;
    messenger.showSnackBar(
        const SnackBar(content: Text('Alle fertigen Artikel als serviert markiert.')));
  }

  // --------------------------------------------------------------- Bezahlen

  /// Zahlweg: Gesamtrechnung, Halbierung, Teilrechnung, danach Belegdruck.
  ///
  /// Wortgleich aus dem frueheren onPressed uebernommen. Der Ablauf ist heikel
  /// genug - nur servierte Artikel duerfen bezahlt werden, Teilzahlungen
  /// erzeugen eigene Verkaufsbelege -, dass eine Umgestaltung und eine
  /// inhaltliche Aenderung nicht in denselben Schritt gehoeren.
  Future<void> _bezahlen() async {
    final ticketsRepo = _ticketsRepo;

    // Betraege fuer die Auswahl - nur servierte Positionen
    final raw = await ticketsRepo.getItemsRaw(_ticketId!);
    final servedUnpaidItems = raw.where((m) {
      final status = (m['status'] ?? 'open').toString();
      return status != 'paid' && status != 'open';
    }).toList();

    int totalUnpaidCents = 0;
    for (final m in servedUnpaidItems) {
      totalUnpaidCents += Money.itemLineTotal(m);
    }

    // Ganzzahlig halbieren: ein ungerader Cent faellt der ersten Haelfte zu.
    final halfAmountCents = (totalUnpaidCents + 1) ~/ 2;

    if (!mounted) return;
    final String? mode = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Zahlungsoptionen', style: Theme.of(ctx).textTheme.titleLarge),
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
        if (mounted) {
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Keine servierten Artikel für 50/50 vorhanden.')),
          );
        }
        return;
      }
      final itemsWithTotal = served
          .map((m) => {...m, 'lineTotalCents': Money.itemLineTotal(m)})
          .toList()
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
        if (mounted) {
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

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setStateDlg) => AlertDialog(
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
                    child: Text('Auswahl-Summe: ${Money.format(selTotalCents)}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
              FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Bezahlen')),
            ],
          ),
        ),
      );
      if (confirmed == true && selected.isNotEmpty) {
        try {
          saleId = await ticketsRepo.paySelectedItems(_ticketId!, selected.toList());
        } catch (e) {
          if (mounted) {
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
              title: const Text('Kein Beleg'),
              onTap: () => Navigator.of(ctx).pop(null),
            ),
          ],
        ),
      ),
    );
    try {
      if (saleId != null && choice == 'bon') {
        await ReceiptService().printSale(saleId);
      } else if (saleId != null && choice == 'bewirtung') {
        await ReceiptService().printHospitalityReceipt(saleId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Druck fehlgeschlagen: $e')));
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Bezahlung erfasst')));
    }
  }

  // ------------------------------------------------------------------ Aufbau

  @override
  Widget build(BuildContext context) {
    final activeEventId = context.watch<EventsProvider>().activeEvent?.id;

    return Scaffold(
      appBar: AppBar(title: Text(_tischName)),
      body: _ticketId == null
          ? Center(
              child: _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!, textAlign: TextAlign.center),
                    )
                  : const CircularProgressIndicator(),
            )
          : StreamBuilder<List<MenuItemEntity>>(
              stream: MenuRepo().streamForService(activeEventId: activeEventId),
              builder: (context, menuSnap) {
                if (menuSnap.hasError) {
                  return Center(child: Text('Speisekarte nicht ladbar: ${menuSnap.error}'));
                }
                if (!menuSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final menu = menuSnap.data!;

                return StreamBuilder<List<TicketItemEntity>>(
                  stream: _ticketsRepo.streamTicketItems(_ticketId!),
                  builder: (context, ticketSnap) {
                    final positionen = ticketSnap.data ?? const <TicketItemEntity>[];

                    final karte = OrderMenuGrid(
                      artikel: menu,
                      kategorie: _kategorie,
                      onKategorie: (k) => setState(() => _kategorie = k),
                      onHinzufuegen: _hinzufuegen,
                      onExtrawunsch: _extrawunsch,
                    );
                    final ticket = OrderTicketPanel(
                      positionen: positionen,
                      karte: menu,
                      onWeniger: (i) => _ticketsRepo.changeItemQty(
                          ticketId: _ticketId!, itemId: i.id, delta: -1),
                      onEntfernen: (i) =>
                          _ticketsRepo.deleteItem(ticketId: _ticketId!, itemId: i.id),
                      onServiert: (i) => _ticketsRepo.markItemServed(_ticketId!, i.id),
                      onAlleServiert: _alleServiert,
                      onSenden: _senden,
                      onBezahlen: _bezahlen,
                    );

                    // Nebeneinander auf dem Tablet, untereinander auf schmalen
                    // Geraeten - die Summe bleibt in beiden Faellen sichtbar.
                    return LayoutBuilder(
                      builder: (context, c) => c.maxWidth >= 840
                          ? Row(children: [
                              Expanded(flex: 62, child: karte),
                              SizedBox(width: 380, child: ticket),
                            ])
                          : Column(children: [
                              Expanded(flex: 3, child: karte),
                              Expanded(flex: 2, child: ticket),
                            ]),
                    );
                  },
                );
              },
            ),
    );
  }
}
