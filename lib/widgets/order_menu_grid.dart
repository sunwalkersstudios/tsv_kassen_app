import 'package:flutter/material.dart';

import '../models/entities.dart';
import '../util/money.dart';

/// Speisekarte als Kachelraster mit Kategoriefiltern.
///
/// Vorher eine lange Liste mit Zwischenueberschriften, in der jeder Artikel
/// eine Zeile mit zwei kleinen Symbolknoepfen war. Auf einem Tablet trifft man
/// Kacheln schneller als Zeilen, und der Filter erspart das Scrollen.
///
/// Bekommt fertige Daten und Rueckrufe, kennt weder Firestore noch Zustand -
/// damit die Entwurfsvorschau dieses Widget zeichnen kann.
class OrderMenuGrid extends StatelessWidget {
  final List<MenuItemEntity> artikel;

  /// Gewaehlte Kategorie, null bedeutet alle.
  final String? kategorie;

  final void Function(String? kategorie)? onKategorie;
  final void Function(MenuItemEntity)? onHinzufuegen;
  final void Function(MenuItemEntity)? onExtrawunsch;

  const OrderMenuGrid({
    super.key,
    required this.artikel,
    this.kategorie,
    this.onKategorie,
    this.onHinzufuegen,
    this.onExtrawunsch,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    if (artikel.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('Keine Artikel in der Karte.\nAnzulegen unter Admin → Speisekarte.',
              textAlign: TextAlign.center, style: t.textTheme.bodyLarge),
        ),
      );
    }

    // Kategorien in der Reihenfolge ihres ersten Auftretens - nicht
    // alphabetisch: die Karte hat eine gewachsene Ordnung.
    final kategorien = <String>[];
    for (final a in artikel) {
      final k = a.category.trim();
      if (k.isNotEmpty && !kategorien.contains(k)) kategorien.add(k);
    }

    final gefiltert =
        kategorie == null ? artikel : artikel.where((a) => a.category == kategorie).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              _Filter(
                label: 'Alle',
                aktiv: kategorie == null,
                onTap: () => onKategorie?.call(null),
              ),
              for (final k in kategorien) ...[
                const SizedBox(width: 8),
                _Filter(
                  label: k,
                  aktiv: kategorie == k,
                  onTap: () => onKategorie?.call(k),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 230,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
            ),
            itemCount: gefiltert.length,
            itemBuilder: (context, i) => _ArtikelKachel(
              artikel: gefiltert[i],
              onHinzufuegen: onHinzufuegen,
              onExtrawunsch: onExtrawunsch,
            ),
          ),
        ),
      ],
    );
  }
}

class _ArtikelKachel extends StatelessWidget {
  final MenuItemEntity artikel;
  final void Function(MenuItemEntity)? onHinzufuegen;
  final void Function(MenuItemEntity)? onExtrawunsch;

  const _ArtikelKachel({required this.artikel, this.onHinzufuegen, this.onExtrawunsch});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    final zurBar = artikel.route == 'bar';

    return Material(
      color: cs.surfaceContainer,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Tippen legt die Position an, langes Tippen fragt nach dem
        // Extrawunsch - schneller als zwei kleine Symbolknoepfe je Zeile.
        onTap: onHinzufuegen == null ? null : () => onHinzufuegen!(artikel),
        onLongPress: onExtrawunsch == null ? null : () => onExtrawunsch!(artikel),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(zurBar ? Icons.local_bar : Icons.restaurant,
                      size: 15, color: cs.onSurfaceVariant),
                  const Spacer(),
                  if (onExtrawunsch != null)
                    Icon(Icons.more_horiz, size: 16, color: cs.onSurfaceVariant),
                ],
              ),
              const Spacer(),
              Text(
                artikel.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.textTheme.titleMedium?.copyWith(height: 1.2),
              ),
              const SizedBox(height: 3),
              Text(
                Money.format(artikel.priceCents),
                style: t.textTheme.bodyLarge
                    ?.copyWith(color: cs.primary, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Filter extends StatelessWidget {
  final String label;
  final bool aktiv;
  final VoidCallback? onTap;
  const _Filter({required this.label, required this.aktiv, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    return Material(
      color: aktiv ? cs.primary : cs.surfaceContainer,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: aktiv ? cs.primary : cs.outlineVariant),
          ),
          child: Text(label,
              style: t.textTheme.labelLarge
                  ?.copyWith(color: aktiv ? cs.onPrimary : cs.onSurface)),
        ),
      ),
    );
  }
}
