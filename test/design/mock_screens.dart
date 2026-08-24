// Entwurfsbildschirme fuer die Gestaltung.
//
// Reine Ansichtsvorlagen mit Beispieldaten - kein Firebase, keine Repos. Sie
// dienen dazu, das Farb- und Schriftschema als echtes Flutter-Bild zu sehen,
// bevor es in die richtigen Bildschirme wandert. Liegt unter test/, wird also
// nicht mitgeliefert.

import 'package:flutter/material.dart';

import 'package:tsv/util/money.dart';

// --------------------------------------------------------------- Tischplan

class MockTablePlan extends StatelessWidget {
  const MockTablePlan({super.key});

  static const _tables = [
    ('1', 4, 3240, 'ready-kitchen', 'Jana', '18:42'),
    ('2', 2, 0, 'free', '', ''),
    ('3', 6, 8750, 'open', 'Marc', '19:05'),
    ('4', 4, 0, 'free', '', ''),
    ('5', 8, 12480, 'ready-bar', 'Jana', '17:58'),
    ('6', 2, 1900, 'open', 'Tim', '19:31'),
    ('7', 4, 0, 'free', '', ''),
    ('8', 10, 24600, 'open', 'Marc', '18:15'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tischplan'),
        actions: [
          _Avatar(initials: 'KE', label: 'Kellner'),
          const SizedBox(width: 12),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Stat(label: 'Offen', value: Money.format(50970), accent: true),
                const SizedBox(width: 12),
                _Stat(label: 'Belegt', value: '5 von 8'),
                const SizedBox(width: 12),
                _Stat(label: 'Fertig zum Servieren', value: '2', highlight: cs.secondary),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 4,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.32,
                children: [
                  for (final (nr, plaetze, cents, status, kellner, seit) in _tables)
                    _TableCard(nummer: nr, plaetze: plaetze, cents: cents,
                        status: status, kellner: kellner, seit: seit),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableCard extends StatelessWidget {
  final String nummer;
  final int plaetze;
  final int cents;
  final String status;
  final String kellner;
  final String seit;
  const _TableCard({required this.nummer, required this.plaetze, required this.cents,
      required this.status, required this.kellner, required this.seit});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    final frei = status == 'free';
    final fertig = status.startsWith('ready');

    final streifen = frei
        ? cs.outlineVariant
        : fertig
            ? cs.secondary
            : cs.primary;

    return Container(
      decoration: BoxDecoration(
        color: frei ? cs.surface : cs.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fertig ? cs.secondary : cs.outlineVariant, width: fertig ? 2 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Statusstreifen: traegt die Information, ist keine Zierde
          Container(height: 5, color: streifen),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nummer,
                          style: t.textTheme.displaySmall?.copyWith(
                              color: frei ? cs.onSurfaceVariant : cs.onSurface)),
                      Row(children: [
                        Icon(Icons.person, size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 2),
                        Text('$plaetze', style: t.textTheme.bodySmall),
                      ]),
                    ],
                  ),
                  if (!frei) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      Text(kellner, style: t.textTheme.bodySmall),
                      Text('  ·  seit $seit', style: t.textTheme.bodySmall),
                    ]),
                  ],
                  const Spacer(),
                  if (fertig)
                    Row(children: [
                      Icon(status == 'ready-bar' ? Icons.local_bar : Icons.restaurant,
                          size: 15, color: cs.secondary),
                      const SizedBox(width: 5),
                      Text(status == 'ready-bar' ? 'Getränke fertig' : 'Speisen fertig',
                          style: t.textTheme.bodySmall?.copyWith(
                              color: cs.secondary, fontWeight: FontWeight.w700)),
                    ])
                  else if (frei)
                    Text('frei', style: t.textTheme.bodySmall)
                  else
                    const SizedBox.shrink(),
                  const SizedBox(height: 4),
                  Text(
                    cents == 0 ? '—' : Money.format(cents),
                    style: t.textTheme.titleLarge?.copyWith(
                      color: cents == 0 ? cs.onSurfaceVariant : cs.primary,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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

class MockCashier extends StatelessWidget {
  const MockCashier({super.key});

  static const _artikel = [
    ('Schnitzel', 41, 51250),
    ('Bier/Radler 0,4', 70, 24500),
    ('Grünkohl', 12, 18600),
    ('Currywurst Pommes', 15, 12750),
    ('Cola, Fanta 0,5', 30, 10500),
    ('Port. Pommes', 22, 7700),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasse'),
        actions: [_Avatar(initials: 'AD', label: 'Admin'), const SizedBox(width: 12)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (final (label, aktiv) in [('Tag', true), ('Woche', false), ('Monat', false), ('Jahr', false)]) ...[
                  _Chip(label: label, aktiv: aktiv),
                  const SizedBox(width: 8),
                ],
                const Spacer(),
                Icon(Icons.chevron_left, color: cs.onSurfaceVariant),
                const SizedBox(width: 14),
                Text('Mittwoch, 22. Oktober 2025', style: t.textTheme.titleMedium),
                const SizedBox(width: 14),
                Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: 20),
            // Die Tageszahl ist die Hauptsache - entsprechend gross
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TAGESUMSATZ',
                          style: t.textTheme.labelSmall?.copyWith(color: cs.onPrimaryContainer)),
                      const SizedBox(height: 6),
                      Text(Money.format(66330),
                          style: t.textTheme.displayLarge?.copyWith(color: cs.onPrimaryContainer)),
                    ],
                  ),
                  const Spacer(),
                  _MiniStat(label: 'Bar', value: Money.format(66330), color: cs.onPrimaryContainer),
                  const SizedBox(width: 28),
                  _MiniStat(label: 'Karte', value: Money.format(0), color: cs.onPrimaryContainer),
                  const SizedBox(width: 28),
                  _MiniStat(label: 'Belege', value: '22', color: cs.onPrimaryContainer),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: _Card(
                      titel: 'Verkäufe je Artikel',
                      child: Column(
                        children: [
                          for (final (name, menge, cents) in _artikel)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              child: Row(
                                children: [
                                  SizedBox(
                                      width: 46,
                                      child: Text('${menge}×',
                                          style: t.textTheme.titleMedium?.copyWith(color: cs.primary))),
                                  Expanded(child: Text(name, style: t.textTheme.bodyLarge)),
                                  Text(Money.format(cents), style: t.textTheme.bodyLarge),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: _Card(
                      titel: 'Kassenbestand',
                      child: Column(
                        children: [
                          _Zeile('Kassenstart', Money.format(15000)),
                          _Zeile('Barumsatz', Money.format(66330)),
                          _Zeile('Einlagen', Money.format(0)),
                          _Zeile('Entnahmen', '− ${Money.format(5000)}'),
                          const SizedBox(height: 8),
                          Divider(color: cs.outlineVariant),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Kasseninhalt', style: t.textTheme.titleMedium),
                              Text(Money.format(76330),
                                  style: t.textTheme.headlineSmall?.copyWith(color: cs.primary)),
                            ],
                          ),
                          const Spacer(),
                          Row(children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.picture_as_pdf, size: 20),
                                label: const Text('PDF'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.print, size: 20),
                                label: const Text('Bon'),
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- Bausteine

class _Zeile extends StatelessWidget {
  final String label;
  final String wert;
  const _Zeile(this.label, this.wert);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyLarge),
            Text(wert, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      );
}

class _Card extends StatelessWidget {
  final String titel;
  final Widget child;
  const _Card({required this.titel, required this.child});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titel.toUpperCase(), style: t.textTheme.labelSmall),
          const SizedBox(height: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final bool accent;
  final Color? highlight;
  const _Stat({required this.label, required this.value, this.accent = false, this.highlight});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: t.textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(value,
                style: t.textTheme.headlineMedium?.copyWith(
                    color: highlight ?? (accent ? cs.primary : cs.onSurface))),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label.toUpperCase(), style: t.textTheme.labelSmall?.copyWith(color: color)),
        const SizedBox(height: 3),
        Text(value, style: t.textTheme.titleLarge?.copyWith(color: color)),
      ],
    );
  }
}

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
