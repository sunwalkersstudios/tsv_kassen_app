// Entwurfsbildschirme fuer die Gestaltung.
//
// Reine Ansichtsvorlagen mit Beispieldaten - kein Firebase, keine Repos. Sie
// dienen dazu, das Farb- und Schriftschema als echtes Flutter-Bild zu sehen,
// bevor es in die richtigen Bildschirme wandert. Liegt unter test/, wird also
// nicht mitgeliefert.

import 'package:flutter/material.dart';

import 'package:tsv/models/cash_day.dart';
import 'package:tsv/models/entities.dart';
import 'package:tsv/models/report_period.dart';
import 'package:tsv/models/sales_summary.dart';
import 'package:tsv/screens/cashier_screen.dart';
import 'package:tsv/widgets/order_menu_grid.dart';
import 'package:tsv/widgets/order_ticket_panel.dart';
import 'package:tsv/widgets/pending_orders_view.dart';
import 'package:tsv/screens/table_plan_screen.dart';

// --------------------------------------------------------------- Tischplan

/// Zeigt den echten Tischplan mit Beispieldaten - kein Nachbau.
class MockTablePlan extends StatelessWidget {
  const MockTablePlan({super.key});

  static final _tische = [
    TableEntity(id: 't1', name: 'Tisch 1', row: 0, col: 0),
    TableEntity(id: 't2', name: 'Tisch 2', row: 0, col: 1),
    TableEntity(id: 't3', name: 'Tisch 3', row: 0, col: 2),
    TableEntity(id: 't4', name: 'Tisch 4', row: 0, col: 3),
    TableEntity(id: 't5', name: 'Tisch 5', row: 1, col: 0),
    TableEntity(id: 't6', name: 'Tisch 6', row: 1, col: 1),
    TableEntity(id: 't7', name: 'Tisch 7', row: 1, col: 2),
    TableEntity(id: 't8', name: 'Tisch 8', row: 1, col: 3),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tischplan'),
        actions: [_Avatar(initials: 'KE', label: 'Kellner'), const SizedBox(width: 12)],
      ),
      body: TablePlanGrid(
        tische: _tische,
        betraege: const {'t1': 3240, 't3': 8750, 't5': 12480, 't6': 1900, 't8': 24600},
        flags: const {
          't1': {'kitchen': true, 'bar': false, 'billable': false},
          't5': {'kitchen': false, 'bar': true, 'billable': false},
          't8': {'kitchen': false, 'bar': false, 'billable': true},
        },
        fertigJeTisch: const {
          't1': {
            'kitchen': [
              {'name': 'Schnitzel'}
            ]
          },
          't5': {
            'bar': [
              {'name': 'Bier'},
              {'name': 'Radler'}
            ]
          },
        },
        merged: false,
      ),
    );
  }
}

// ------------------------------------------------------------- Bestellung

/// Zeigt die echte Bestellmaske mit Beispieldaten - kein Nachbau.
class MockOrder extends StatelessWidget {
  const MockOrder({super.key});

  static final _karte = [
    MenuItemEntity(id: 'm1', name: 'Schnitzel', priceCents: 1250, category: 'Speisen', route: 'kitchen', favorite: true),
    MenuItemEntity(id: 'm2', name: 'Currywurst Pommes', priceCents: 850, category: 'Speisen', route: 'kitchen'),
    MenuItemEntity(id: 'm3', name: 'Grünkohl', priceCents: 1550, category: 'Speisen', route: 'kitchen'),
    MenuItemEntity(id: 'm4', name: 'Port. Pommes', priceCents: 350, category: 'Speisen', route: 'kitchen'),
    MenuItemEntity(id: 'm5', name: 'Bier/Radler 0,4', priceCents: 350, category: 'Getränke', route: 'bar', favorite: true),
    MenuItemEntity(id: 'm6', name: 'Cola, Fanta 0,5', priceCents: 350, category: 'Getränke', route: 'bar', favorite: true),
    MenuItemEntity(id: 'm7', name: 'A-Schorle', priceCents: 350, category: 'Getränke', route: 'bar'),
    MenuItemEntity(id: 'm8', name: 'Kaffee / Tee', priceCents: 200, category: 'Getränke', route: 'bar'),
    MenuItemEntity(id: 'm9', name: 'Wein 0,2', priceCents: 350, category: 'Getränke', route: 'bar'),
    MenuItemEntity(id: 'm10', name: 'Bratwurst', priceCents: 300, category: 'Grillhütte', route: 'kitchen'),
    MenuItemEntity(id: 'm11', name: 'Nachos', priceCents: 400, category: 'Grillhütte', route: 'kitchen'),
    MenuItemEntity(id: 'm12', name: 'Wasser 0,5', priceCents: 300, category: 'Getränke', route: 'bar'),
  ];

  static final _positionen = [
    TicketItemEntity(id: 'i1', menuItemId: 'm1', qty: 2, route: 'kitchen', status: TicketStatus.open),
    TicketItemEntity(id: 'i2', menuItemId: 'm5', qty: 3, route: 'bar', status: TicketStatus.sentToKitchen),
    TicketItemEntity(id: 'i3', menuItemId: 'm4', qty: 1, route: 'kitchen', status: TicketStatus.ready),
    TicketItemEntity(id: 'i4', menuItemId: 'm3', qty: 1, route: 'kitchen', notes: 'ohne Speck', status: TicketStatus.open),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tisch 3'),
        actions: [_Avatar(initials: 'KE', label: 'Kellner'), const SizedBox(width: 12)],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 62,
            child: OrderMenuGrid(
              artikel: _karte,
              onKategorie: (_) {},
              onHinzufuegen: (_) {},
              onExtrawunsch: (_) {},
            ),
          ),
          SizedBox(
            width: 380,
            child: OrderTicketPanel(
              positionen: _positionen,
              karte: _karte,
              onWeniger: (_) {},
              onEntfernen: (_) {},
              onServiert: (_) {},
              onAlleServiert: () {},
              onSenden: () {},
              onBezahlen: () {},
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ Kasse

/// Zeigt die echte Kasse mit Beispieldaten - kein Nachbau.
class MockCashier extends StatelessWidget {
  const MockCashier({super.key});

  static List<Map<String, dynamic>> _verkaeufe() {
    final artikel = [
      ('Schnitzel', 41, 1250),
      ('Bier/Radler 0,4', 70, 350),
      ('Grünkohl', 12, 1550),
      ('Currywurst Pommes', 15, 850),
      ('Cola, Fanta 0,5', 30, 350),
      ('Port. Pommes', 22, 350),
    ];
    // Ein Beleg je Artikel reicht: die Auswertung fasst ohnehin zusammen.
    return [
      for (final (name, menge, preis) in artikel)
        {
          'day': '2025-10-22',
          'totalCents': menge * preis,
          'paymentMethod': 'cash',
          'items': [
            {'name': name, 'qty': menge, 'lineTotalCents': menge * preis}
          ],
        },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final summary = SalesSummary.fromSales(_verkaeufe());
    const kassentag = CashDay(
      day: '2025-10-22',
      openingCents: 15000,
      depositCents: 0,
      withdrawalCents: 5000,
    );
    final drawer = kassentag.drawerCents(summary.cashCents);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasse'),
        leading: const Icon(Icons.arrow_back),
        actions: [_Avatar(initials: 'AD', label: 'Admin'), const SizedBox(width: 12)],
      ),
      body: CashierBody(
        onPeriod: (_) {},
        onPickDate: () {},
        onEditCashDay: (_) {},
        onExport: (_) {},
        onResetDay: (_) {},
        onPrintDay: () {},
        period: ReportPeriod(PeriodKind.day, DateTime(2025, 10, 22)),
        summary: summary,
        cashDays: const {'2025-10-22': kassentag},
        opening: kassentag.openingCents,
        deposit: kassentag.depositCents,
        withdrawal: kassentag.withdrawalCents,
        drawer: drawer,
      ),
    );
  }
}


// ------------------------------------------------------------------ Kueche

/// Zeigt die echte Kuechenansicht mit Beispieldaten - kein Nachbau.
class MockKitchen extends StatelessWidget {
  const MockKitchen({super.key});

  /// Fester Bezugszeitpunkt, damit die Wartezeiten in den Bildern
  /// reproduzierbar bleiben.
  static final _jetzt = DateTime(2025, 10, 22, 19, 30);

  static Map<String, dynamic> _pos(
      String ticket, String tisch, String name, int qty, int vorMinuten,
      {String notes = '', String route = 'kitchen', String status = 'sentToKitchen'}) {
    return {
      'ticketId': ticket,
      'tableId': tisch,
      'itemId': '$ticket-$name',
      'name': name,
      'qty': qty,
      'notes': notes,
      'route': route,
      'status': status,
      'createdAt': _jetzt.subtract(Duration(minutes: vorMinuten)),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Küche'),
        actions: [_Avatar(initials: 'KÜ', label: 'Küche'), const SizedBox(width: 12)],
      ),
      body: PendingOrdersView(
        route: 'kitchen',
        jetzt: _jetzt,
        // Leere Rueckrufe: ohne sie zeichnet Flutter die Schaltflaechen als
        // deaktiviert, und das Bild zeigte einen Zustand, den es im Betrieb
        // nicht gibt.
        onItemFertig: (_, __) {},
        onTicketFertig: (_) {},
        tische: [
          TableEntity(id: 't3', name: 'Tisch 3', row: 0, col: 0),
          TableEntity(id: 't5', name: 'Tisch 5', row: 0, col: 1),
          TableEntity(id: 't8', name: 'Tisch 8', row: 0, col: 2),
        ],
        positionen: [
          _pos('a', 't8', 'Schnitzel', 4, 28),
          _pos('a', 't8', 'Grünkohl', 2, 28, notes: 'einmal ohne Speck'),
          _pos('a', 't8', 'Port. Pommes', 3, 28, status: 'ready'),
          _pos('b', 't3', 'Currywurst Pommes', 2, 17),
          _pos('b', 't3', 'Schnitzel', 1, 17, notes: 'gut durch'),
          _pos('c', 't5', 'Grünkohl', 1, 4),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- Bausteine

class _Avatar extends StatelessWidget {
  final String initials;
  final String label;
  const _Avatar({required this.initials, required this.label});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(width: 8),
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
          child: Text(initials,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, color: cs.onPrimaryContainer)),
        ),
      ],
    );
  }
}
