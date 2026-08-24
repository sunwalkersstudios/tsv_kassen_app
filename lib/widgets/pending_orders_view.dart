import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/entities.dart';

/// Offene Bestellungen einer Route als Bon-Karten - die Ansicht fuer Kueche
/// und Bar.
///
/// Beide Bildschirme waren zuvor fast zeichengleiche Kopien voneinander; die
/// Darstellung liegt jetzt einmal hier. Zwei Dinge sind dabei geradegezogen:
///
/// - In jeder Karte steckte ein `FutureBuilder`, dessen Future direkt im
///   `build` erzeugt wurde. Das loeste bei jedem Neuzeichnen eine
///   Firestore-Abfrage je Ticket aus, nur um den Tischnamen zu holen - der
///   ohnehin schon im Datenstrom liegt.
/// - Die Wartezeit war nirgends zu sehen. In einer Kueche ist genau das die
///   Information, nach der sortiert wird.
///
/// Bekommt fertige Daten und Rueckrufe, kennt weder Firestore noch Provider -
/// damit die Entwurfsvorschau unter test/design dieses Widget zeichnen kann.
class PendingOrdersView extends StatelessWidget {
  /// Offene Positionen, wie sie `streamPendingForRoute` liefert.
  final List<Map<String, dynamic>> positionen;

  /// Tische zum Aufloesen der Namen.
  final List<TableEntity> tische;

  /// Route dieser Ansicht: 'kitchen' oder 'bar'.
  final String route;

  /// True, wenn Kueche und Bar zusammengelegt sind.
  final bool merged;

  /// Zeitpunkt, gegen den die Wartezeit gerechnet wird. In der Vorschau
  /// festgesetzt, damit die Bilder reproduzierbar bleiben.
  final DateTime? jetzt;

  final void Function(String ticketId, String itemId)? onItemFertig;
  final void Function(String ticketId)? onTicketFertig;

  const PendingOrdersView({
    super.key,
    required this.positionen,
    required this.tische,
    required this.route,
    this.merged = false,
    this.jetzt,
    this.onItemFertig,
    this.onTicketFertig,
  });

  bool get _istKueche => route == 'kitchen';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    if (positionen.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_istKueche ? Icons.restaurant : Icons.local_bar,
                  size: 44, color: t.colorScheme.onSurfaceVariant),
              const SizedBox(height: 14),
              Text('Nichts offen', style: t.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                merged
                    ? 'Alle Bestellungen sind erledigt.'
                    : _istKueche
                        ? 'Für die Küche liegt nichts an.'
                        : 'Für die Bar liegt nichts an.',
                style: t.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    // Nach Ticket buendeln - ein Bon je Tisch.
    final jeTicket = <String, List<Map<String, dynamic>>>{};
    for (final p in positionen) {
      jeTicket.putIfAbsent((p['ticketId'] ?? '').toString(), () => []).add(p);
    }

    // Aelteste zuerst: was am laengsten wartet, gehoert nach oben.
    final tickets = jeTicket.entries.toList()
      ..sort((a, b) => _aeltester(a.value).compareTo(_aeltester(b.value)));

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 380,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.95,
      ),
      itemCount: tickets.length,
      itemBuilder: (context, i) => _BonKarte(
        ticketId: tickets[i].key,
        positionen: tickets[i].value,
        tischName: _tischName(tickets[i].value),
        wartetSeit: _aeltester(tickets[i].value),
        jetzt: jetzt ?? DateTime.now(),
        zeigeRoute: merged,
        onItemFertig: onItemFertig,
        onTicketFertig: onTicketFertig,
      ),
    );
  }

  /// Aeltester Zeitstempel eines Bons - danach richtet sich die Reihenfolge.
  DateTime _aeltester(List<Map<String, dynamic>> ps) {
    DateTime? aeltest;
    for (final p in ps) {
      final ts = p['createdAt'];
      final d = ts is Timestamp ? ts.toDate() : (ts is DateTime ? ts : null);
      if (d != null && (aeltest == null || d.isBefore(aeltest))) aeltest = d;
    }
    return aeltest ?? DateTime.now();
  }

  /// Tischname aus den Stammdaten. Der Datenstrom liefert die tableId bereits
  /// mit, eine Nachfrage bei Firestore eruebrigt sich.
  String _tischName(List<Map<String, dynamic>> ps) {
    final id = ps.map((p) => (p['tableId'] ?? '').toString()).firstWhere(
          (s) => s.isNotEmpty,
          orElse: () => '',
        );
    if (id.isEmpty) return 'Tisch unbekannt';
    for (final t in tische) {
      if (t.id == id) return t.name;
    }
    return 'Tisch unbekannt';
  }
}

class _BonKarte extends StatelessWidget {
  final String ticketId;
  final List<Map<String, dynamic>> positionen;
  final String tischName;
  final DateTime wartetSeit;
  final DateTime jetzt;
  final bool zeigeRoute;
  final void Function(String, String)? onItemFertig;
  final void Function(String)? onTicketFertig;

  const _BonKarte({
    required this.ticketId,
    required this.positionen,
    required this.tischName,
    required this.wartetSeit,
    required this.jetzt,
    required this.zeigeRoute,
    this.onItemFertig,
    this.onTicketFertig,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    final minuten = jetzt.difference(wartetSeit).inMinutes;
    // Ab einer Viertelstunde faellt es auf, ab 25 Minuten wird es dringend.
    final dringlichkeit = minuten >= 25
        ? cs.error
        : minuten >= 15
            ? cs.tertiary
            : cs.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: minuten >= 25 ? cs.error : cs.outlineVariant,
          width: minuten >= 25 ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 5, color: dringlichkeit),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(tischName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.headlineSmall),
                ),
                Row(children: [
                  Icon(Icons.schedule, size: 15, color: dringlichkeit),
                  const SizedBox(width: 4),
                  Text('$minuten min',
                      style: t.textTheme.bodyMedium
                          ?.copyWith(color: dringlichkeit, fontWeight: FontWeight.w700)),
                ]),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              children: [
                for (final p in positionen) _positionsZeile(context, p),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: FilledButton.icon(
              onPressed: onTicketFertig == null ? null : () => onTicketFertig!(ticketId),
              icon: const Icon(Icons.done_all),
              label: const Text('Bon fertig'),
              style: FilledButton.styleFrom(
                backgroundColor: cs.secondary,
                foregroundColor: cs.onSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _positionsZeile(BuildContext context, Map<String, dynamic> p) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    final name = ((p['name'] ?? '').toString().trim().isNotEmpty)
        ? p['name'].toString()
        : 'Unbekannt';
    final qty = (p['qty'] as num?)?.toInt() ?? 1;
    final notes = (p['notes'] ?? '').toString();
    final status = (p['status'] ?? 'open').toString();
    final route = (p['route'] ?? '').toString();
    final offen = status == 'open' || status == 'sentToKitchen';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$qty',
                style: t.textTheme.titleMedium?.copyWith(color: cs.onPrimaryContainer)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: t.textTheme.titleMedium),
                if (notes.isNotEmpty)
                  Text(notes,
                      style: t.textTheme.bodySmall
                          ?.copyWith(color: cs.tertiary, fontWeight: FontWeight.w700)),
                if (zeigeRoute && route.isNotEmpty)
                  Text(route == 'bar' ? 'Bar' : 'Küche', style: t.textTheme.bodySmall),
              ],
            ),
          ),
          if (offen)
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              tooltip: 'Position fertig',
              color: cs.secondary,
              onPressed: onItemFertig == null
                  ? null
                  : () => onItemFertig!(
                        (p['ticketId'] ?? '').toString(),
                        (p['itemId'] ?? '').toString(),
                      ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(Icons.check_circle, size: 20, color: cs.secondary),
            ),
        ],
      ),
    );
  }
}
