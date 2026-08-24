import 'package:flutter/material.dart';

import '../models/entities.dart';
import '../util/money.dart';

/// Laufender Beleg eines Tisches - Positionen, Summe und die beiden
/// Hauptaktionen.
///
/// Vorher standen die Ticketpositionen unterhalb der gesamten Speisekarte in
/// derselben Liste: um zu sehen, was bestellt ist, musste man an der ganzen
/// Karte vorbeiscrollen, und die Summe stand nirgends. Jetzt ist beides
/// staendig sichtbar.
///
/// Die Statusfarben kamen aus fest verdrahteten Werten (Colors.green.shade50,
/// blue.shade50, red.shade50) und gingen am Farbschema vorbei; im dunklen
/// Modus war der Text auf diesen Flaechen kaum lesbar.
class OrderTicketPanel extends StatelessWidget {
  final List<TicketItemEntity> positionen;

  /// Speisekarte zum Aufloesen von Name und Preis.
  final List<MenuItemEntity> karte;

  final void Function(TicketItemEntity)? onWeniger;
  final void Function(TicketItemEntity)? onEntfernen;
  final void Function(TicketItemEntity)? onServiert;
  final VoidCallback? onAlleServiert;
  final VoidCallback? onSenden;
  final VoidCallback? onBezahlen;

  const OrderTicketPanel({
    super.key,
    required this.positionen,
    required this.karte,
    this.onWeniger,
    this.onEntfernen,
    this.onServiert,
    this.onAlleServiert,
    this.onSenden,
    this.onBezahlen,
  });

  MenuItemEntity? _artikel(String menuItemId) {
    for (final m in karte) {
      if (m.id == menuItemId) return m;
    }
    return null;
  }

  int get _summeCents {
    var s = 0;
    for (final p in positionen) {
      s += (_artikel(p.menuItemId)?.priceCents ?? 0) * p.qty;
    }
    return s;
  }

  int get _fertigAnzahl => positionen
      .where((p) =>
          p.status == TicketStatus.ready && (p.route == 'kitchen' || p.route == 'bar'))
      .length;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        border: Border(left: BorderSide(color: cs.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text('BESTELLUNG', style: t.textTheme.labelSmall),
                const Spacer(),
                Text(
                  positionen.isEmpty
                      ? ''
                      : '${positionen.length} ${positionen.length == 1 ? 'Position' : 'Positionen'}',
                  style: t.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (_fertigAnzahl > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: OutlinedButton.icon(
                onPressed: onAlleServiert,
                icon: const Icon(Icons.done_all, size: 20),
                label: Text('Alle serviert ($_fertigAnzahl)'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  foregroundColor: cs.secondary,
                  side: BorderSide(color: cs.secondary),
                ),
              ),
            ),
          Expanded(
            child: positionen.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Noch nichts bestellt.\nArtikel links antippen.',
                          textAlign: TextAlign.center, style: t.textTheme.bodyMedium),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [for (final p in positionen) _zeile(context, p)],
                  ),
          ),
          Divider(height: 1, color: cs.outlineVariant),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Summe', style: t.textTheme.titleMedium),
                    const Spacer(),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(Money.format(_summeCents),
                            style: t.textTheme.displaySmall?.copyWith(color: cs.primary)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: positionen.isEmpty ? null : onSenden,
                      icon: const Icon(Icons.send, size: 20),
                      label: const Text('Senden'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: positionen.isEmpty ? null : onBezahlen,
                      icon: const Icon(Icons.payments, size: 20),
                      label: const Text('Kassieren'),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _zeile(BuildContext context, TicketItemEntity p) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    final m = _artikel(p.menuItemId);
    final name = m?.name ?? 'Unbekannt (${p.menuItemId})';
    final cents = (m?.priceCents ?? 0) * p.qty;
    final ueberRoute = p.route == 'kitchen' || p.route == 'bar';

    // Statusfarbe aus dem Schema statt aus fest verdrahteten Materialtoenen.
    final (farbe, wort) = switch (p.status) {
      TicketStatus.ready => (cs.secondary, 'fertig'),
      TicketStatus.served => (cs.onSurfaceVariant, 'serviert'),
      TicketStatus.paid => (cs.onSurfaceVariant, 'bezahlt'),
      TicketStatus.sentToKitchen => (cs.tertiary, 'in Arbeit'),
      TicketStatus.open => (cs.onSurfaceVariant, 'neu'),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      child: Row(
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
            child: Text('${p.qty}',
                style: t.textTheme.titleMedium?.copyWith(color: cs.onPrimaryContainer)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.bodyLarge),
                Row(children: [
                  if (ueberRoute)
                    Text(wort,
                        style: t.textTheme.bodySmall
                            ?.copyWith(color: farbe, fontWeight: FontWeight.w700)),
                  if (p.notes.isNotEmpty) ...[
                    if (ueberRoute) Text('  ·  ', style: t.textTheme.bodySmall),
                    Flexible(
                      child: Text(p.notes,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.textTheme.bodySmall?.copyWith(color: cs.tertiary)),
                    ),
                  ],
                ]),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(Money.format(cents), style: t.textTheme.bodyLarge),
          if (p.status == TicketStatus.open) ...[
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              tooltip: p.qty > 1 ? 'Eine weniger' : 'Position entfernen',
              onPressed: onWeniger == null ? null : () => onWeniger!(p),
            ),
            if (p.qty > 1)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: 'Ganze Position entfernen',
                onPressed: onEntfernen == null ? null : () => onEntfernen!(p),
              ),
          ] else if (ueberRoute && p.status == TicketStatus.ready)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.done_all, size: 20),
              color: cs.secondary,
              tooltip: 'Als serviert markieren',
              onPressed: onServiert == null ? null : () => onServiert!(p),
            ),
        ],
      ),
    );
  }
}
