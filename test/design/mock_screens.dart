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
import 'package:tsv/widgets/pending_orders_view.dart';
import 'package:tsv/screens/table_plan_screen.dart';
import 'package:tsv/util/money.dart';

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

class MockOrder extends StatelessWidget {
  const MockOrder({super.key});

  static const _kategorien = ['Alle', 'Getränke', 'Speisen', 'Grillhütte'];
  static const _artikel = [
    ('Schnitzel', 1250, 'Speisen'),
    ('Currywurst Pommes', 850, 'Speisen'),
    ('Grünkohl', 1550, 'Speisen'),
    ('Port. Pommes', 350, 'Speisen'),
    ('Bier/Radler 0,4', 350, 'Getränke'),
    ('Cola, Fanta 0,5', 350, 'Getränke'),
    ('A-Schorle', 350, 'Getränke'),
    ('Kaffee / Tee', 200, 'Getränke'),
    ('Bratwurst', 300, 'Grillhütte'),
    ('Nachos', 400, 'Grillhütte'),
    ('Wein 0,2', 350, 'Getränke'),
    ('Wasser 0,5', 300, 'Getränke'),
  ];
  static const _ticket = [
    ('Schnitzel', 2, 2500, 'open'),
    ('Bier/Radler 0,4', 3, 1050, 'sent'),
    ('Port. Pommes', 1, 350, 'ready'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tisch 3'),
        actions: [_Avatar(initials: 'KE', label: 'Kellner'), const SizedBox(width: 12)],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Artikelauswahl als Kachelraster - schneller zu treffen als eine Liste
          Expanded(
            flex: 62,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      for (final k in _kategorien) ...[
                        _Chip(label: k, aktiv: k == 'Alle'),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.7,
                      children: [
                        for (final (name, cents, kat) in _artikel)
                          _ItemTile(name: name, cents: cents, kategorie: kat),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Laufender Beleg
          Expanded(
            flex: 38,
            child: Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainer,
                border: Border(left: BorderSide(color: cs.outlineVariant)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('BESTELLUNG', style: t.textTheme.labelSmall),
                  const SizedBox(height: 14),
                  for (final (name, menge, cents, status) in _ticket) ...[
                    _TicketLine(name: name, menge: menge, cents: cents, status: status),
                    const SizedBox(height: 10),
                  ],
                  const Spacer(),
                  Divider(color: cs.outlineVariant),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Summe', style: t.textTheme.titleMedium),
                      Text(Money.format(3900), style: t.textTheme.displaySmall?.copyWith(color: cs.primary)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.send, size: 20),
                        label: const Text('Senden'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.payments, size: 20),
                        label: const Text('Kassieren'),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final String name;
  final int cents;
  final String kategorie;
  const _ItemTile({required this.name, required this.cents, required this.kategorie});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    final istGetraenk = kategorie == 'Getränke';
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(istGetraenk ? Icons.local_bar : Icons.restaurant,
              size: 16, color: cs.onSurfaceVariant),
          const Spacer(),
          Text(name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.textTheme.titleMedium?.copyWith(height: 1.2)),
          const SizedBox(height: 3),
          Text(Money.format(cents),
              style: t.textTheme.bodyLarge?.copyWith(
                  color: cs.primary, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _TicketLine extends StatelessWidget {
  final String name;
  final int menge;
  final int cents;
  final String status;
  const _TicketLine({required this.name, required this.menge, required this.cents, required this.status});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    final (farbe, wort) = switch (status) {
      'ready' => (cs.secondary, 'fertig'),
      'sent' => (cs.tertiary, 'in Arbeit'),
      _ => (cs.onSurfaceVariant, 'neu'),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$menge',
              style: t.textTheme.titleMedium?.copyWith(color: cs.onPrimaryContainer)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: t.textTheme.bodyLarge),
              Text(wort,
                  style: t.textTheme.bodySmall?.copyWith(color: farbe, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        Text(Money.format(cents), style: t.textTheme.bodyLarge),
      ],
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

class _Chip extends StatelessWidget {
  final String label;
  final bool aktiv;
  const _Chip({required this.label, required this.aktiv});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      decoration: BoxDecoration(
        color: aktiv ? cs.primary : cs.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: aktiv ? cs.primary : cs.outlineVariant),
      ),
      child: Text(label,
          style: t.textTheme.labelLarge?.copyWith(color: aktiv ? cs.onPrimary : cs.onSurface)),
    );
  }
}

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
