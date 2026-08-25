import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/entities.dart';
import '../repo/tickets_repo.dart';
import '../state/auth_provider.dart';
import '../state/settings_provider.dart';
import '../state/tables_provider.dart';
import '../util/money.dart';
import '../widgets/user_menu_button.dart';
import '../widgets/connection_indicator.dart';

/// Tischplan als Kachelraster.
///
/// Loest die frueheren Karten mit Farbverlauf und einem Stapel aus bis zu fuenf
/// Chips ab. Die Chips trugen fest verdrahtete Farben (Colors.orange.shade200
/// und Verwandte), die am Farbschema vorbeigingen und im dunklen Modus nicht
/// funktionierten.
///
/// Der Statusstreifen oben traegt die Information, die im Betrieb zaehlt:
/// gruen heisst fertig zum Servieren, kupfer heisst belegt, grau heisst frei.
/// Was in einer Sekunde erkennbar sein muss, steht in der Farbe - nicht im Text.
class TablePlanScreen extends StatelessWidget {
  const TablePlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tables = context.watch<TablesProvider>();
    final auth = context.watch<AuthProvider>();
    final merged = context.watch<SettingsProvider>().mergeKitchenBar;
    final ticketsRepo = TicketsRepo();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tischplan'),
        actions: const [ConnectionIndicator(), UserMenuButton()],
      ),
      body: auth.user == null
          ? const _Hinweis('Bitte anmelden.')
          : StreamBuilder<Map<String, int>>(
              stream: ticketsRepo.streamOpenAmountsByTable(),
              builder: (context, betraegeSnap) {
                final betraege = betraegeSnap.data ?? const <String, int>{};

                return StreamBuilder<Map<String, Map<String, bool>>>(
                  stream: ticketsRepo.streamRouteFlagsAll(),
                  builder: (context, flagsSnap) {
                    final flags = flagsSnap.data ?? const <String, Map<String, bool>>{};

                    return StreamBuilder<Map<String, Map<String, List<Map<String, dynamic>>>>>(
                      stream: ticketsRepo.streamReadyItemsByTable(),
                      builder: (context, fertigSnap) {
                        final fertigJeTisch = fertigSnap.data ?? const {};

                        if (tables.tables.isEmpty) {
                          return const _Hinweis(
                              'Keine Tische vorhanden.\nAnlegen unter Admin → Tische.');
                        }
                        final sichtbar = tables.tables.where((t) => t.active).toList();
                        if (sichtbar.isEmpty) {
                          return const _Hinweis(
                              'Kein Tisch ist aktiv.\nAktivieren unter Admin → Tische.');
                        }

                        return TablePlanGrid(
                          tische: sichtbar,
                          betraege: betraege,
                          flags: flags,
                          fertigJeTisch: fertigJeTisch,
                          merged: merged,
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}

/// Reine Darstellung des Rasters - bekommt fertige Daten und kennt weder
/// Firestore noch Provider.
///
/// Oeffentlich, damit die Entwurfsvorschau unter test/design genau dieses
/// Widget zeichnen kann statt einer Parallelfassung, die mit der Zeit
/// auseinanderlaeuft.
class TablePlanGrid extends StatelessWidget {
  final List<TableEntity> tische;
  final Map<String, int> betraege;
  final Map<String, Map<String, bool>> flags;
  final Map<String, Map<String, List<Map<String, dynamic>>>> fertigJeTisch;
  final bool merged;

  const TablePlanGrid({
    super.key,
    required this.tische,
    required this.betraege,
    required this.flags,
    required this.fertigJeTisch,
    required this.merged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final offenGesamt = tische.fold<int>(0, (s, t) => s + (betraege[t.id] ?? 0));
    final belegt = tische.where((t) => (betraege[t.id] ?? 0) > 0).length;
    final fertig = tische.where((t) {
      final f = flags[t.id] ?? const {};
      return f['kitchen'] == true || f['bar'] == true;
    }).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              _Kennzahl(label: 'Offen', wert: Money.format(offenGesamt), farbe: cs.primary),
              const SizedBox(width: 12),
              _Kennzahl(label: 'Belegt', wert: '$belegt von ${tische.length}'),
              const SizedBox(width: 12),
              _Kennzahl(
                label: 'Fertig zum Servieren',
                wert: '$fertig',
                farbe: fertig > 0 ? cs.secondary : null,
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 260,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.3,
            ),
            itemCount: tische.length,
            itemBuilder: (context, i) {
              final t = tische[i];
              final f = flags[t.id] ?? const {'kitchen': false, 'bar': false, 'billable': false};
              return _TischKachel(
                tisch: t,
                cents: betraege[t.id] ?? 0,
                kuecheFertig: f['kitchen'] == true,
                barFertig: f['bar'] == true,
                abrechenbar: f['billable'] == true,
                fertigeSpeisen: fertigJeTisch[t.id]?['kitchen'] ?? const [],
                fertigeGetraenke: fertigJeTisch[t.id]?['bar'] ?? const [],
                merged: merged,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TischKachel extends StatelessWidget {
  final TableEntity tisch;
  final int cents;
  final bool kuecheFertig;
  final bool barFertig;
  final bool abrechenbar;
  final List<Map<String, dynamic>> fertigeSpeisen;
  final List<Map<String, dynamic>> fertigeGetraenke;
  final bool merged;

  const _TischKachel({
    required this.tisch,
    required this.cents,
    required this.kuecheFertig,
    required this.barFertig,
    required this.abrechenbar,
    required this.fertigeSpeisen,
    required this.fertigeGetraenke,
    required this.merged,
  });

  /// "Tisch 7" wird zu ("Tisch", "7") - die Nummer traegt gross, das Wort klein.
  static (String?, String) _teileNamen(String name) {
    final m = RegExp(r'^(.*?)\s+(\S+)$').firstMatch(name.trim());
    if (m == null) return (null, name);
    return (m.group(1), m.group(2)!);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    final fertig = kuecheFertig || barFertig;
    final belegt = cents > 0 || fertig || abrechenbar;
    final (praefix, nummer) = _teileNamen(tisch.name);

    final streifen = !belegt
        ? cs.outlineVariant
        : fertig
            ? cs.secondary
            : cs.primary;

    return Material(
      color: belegt ? cs.surfaceContainer : cs.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/tables/order/${tisch.id}'),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: fertig ? cs.secondary : cs.outlineVariant,
              width: fertig ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Statusstreifen: traegt Information, ist keine Zierde
              Container(height: 5, color: streifen),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (praefix != null)
                        Text(praefix.toUpperCase(), style: t.textTheme.labelSmall),
                      Text(
                        nummer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.textTheme.displaySmall?.copyWith(
                          color: belegt ? cs.onSurface : cs.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      ..._statusZeilen(context),
                      const SizedBox(height: 4),
                      Text(
                        cents == 0 ? '—' : Money.format(cents),
                        style: t.textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                          color: cents == 0 ? cs.onSurfaceVariant : cs.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Hoechstens zwei Zeilen - der fruehere Stapel aus bis zu fuenf Chips war
  /// auf einer Kachel nicht mehr zu erfassen.
  List<Widget> _statusZeilen(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    Widget zeile(IconData icon, String text, Color farbe) => Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
            children: [
              Icon(icon, size: 15, color: farbe),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.bodySmall?.copyWith(color: farbe, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );

    final zeilen = <Widget>[];

    if (kuecheFertig || fertigeSpeisen.isNotEmpty) {
      final n = fertigeSpeisen.length;
      zeilen.add(zeile(
        Icons.restaurant,
        n == 1
            ? '${fertigeSpeisen.first['name'] ?? 'Speise'} fertig'
            : n > 1
                ? '$n Speisen fertig'
                : 'Speisen fertig',
        cs.secondary,
      ));
    }
    if (barFertig || fertigeGetraenke.isNotEmpty) {
      final n = fertigeGetraenke.length;
      zeilen.add(zeile(
        Icons.local_bar,
        n == 1
            ? '${fertigeGetraenke.first['name'] ?? 'Getränk'} fertig'
            : n > 1
                ? '$n Getränke fertig'
                : merged
                    ? 'Getränke fertig (zusammengelegt)'
                    : 'Getränke fertig',
        cs.secondary,
      ));
    }
    if (zeilen.isEmpty && abrechenbar) {
      zeilen.add(zeile(Icons.receipt_long, 'Bereit zum Kassieren', cs.tertiary));
    }
    if (zeilen.isEmpty && cents == 0) {
      zeilen.add(Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text('frei', style: t.textTheme.bodySmall),
      ));
    }
    return zeilen.take(2).toList();
  }
}

class _Kennzahl extends StatelessWidget {
  final String label;
  final String wert;
  final Color? farbe;
  const _Kennzahl({required this.label, required this.wert, this.farbe});

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
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(wert,
                  style: t.textTheme.headlineMedium?.copyWith(color: farbe ?? cs.onSurface)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hinweis extends StatelessWidget {
  final String text;
  const _Hinweis(this.text);

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
}
