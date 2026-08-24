import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/cash_day.dart';
import '../models/report_period.dart';
import '../models/sales_summary.dart';
import '../repo/cash_day_repo.dart';
import '../repo/sales_repo.dart';
import '../util/money.dart';
import '../util/receipt_service.dart';
import '../util/report_export.dart';

/// Kasse mit Auswertung fuer Tag, Woche, Monat und Jahr.
///
/// Loest die frueheren sieben fest verdrahteten Tage ab: der Zeitraum wird
/// ueber Pfeile oder den Kalender gewaehlt und reicht so weit zurueck wie es
/// Verkaeufe gibt. Kassenstart, Einlagen und Entnahmen liegen in Firestore
/// statt im lokalen Geraetespeicher.
class CashierScreen extends StatefulWidget {
  const CashierScreen({super.key});

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  final _salesRepo = SalesRepo();
  final _cashRepo = CashDayRepo();

  ReportPeriod _period = ReportPeriod.today();
  late Future<Map<String, CashDay>> _cashFuture;

  /// Aeltester Tag mit Umsatz - begrenzt den Kalender nach unten.
  DateTime? _firstSaleDate;

  @override
  void initState() {
    super.initState();
    _cashFuture = _cashRepo.fetchRange(_period.fromKey, _period.toKey);
    _loadBounds();
  }

  Future<void> _loadBounds() async {
    final first = await _salesRepo.firstSaleDay();
    if (!mounted || first == null) return;
    setState(() => _firstSaleDate = DateTime.tryParse(first));
  }

  void _setPeriod(ReportPeriod p) {
    setState(() {
      _period = p;
      _cashFuture = _cashRepo.fetchRange(p.fromKey, p.toKey);
    });
  }

  void _reloadCash() {
    setState(() {
      _cashFuture = _cashRepo.fetchRange(_period.fromKey, _period.toKey);
    });
  }

  // ------------------------------------------------------------- Kassenwerte

  Future<void> _editCashDay(CashDay current) async {
    final opening = TextEditingController(text: Money.plain(current.openingCents));
    final deposit = TextEditingController(text: Money.plain(current.depositCents));
    final withdrawal = TextEditingController(text: Money.plain(current.withdrawalCents));
    final note = TextEditingController(text: current.note);

    Widget amountField(String label, TextEditingController c) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: label,
              suffixText: '€',
              border: const OutlineInputBorder(),
            ),
          ),
        );

    // Messenger vor dem Dialog greifen: danach ist der BuildContext ueber
    // einen async-Sprung hinweg nicht mehr sicher zu benutzen.
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Kassenwerte · ${current.day}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              amountField('Kassenstart (Wechselgeld)', opening),
              amountField('Einlagen', deposit),
              amountField('Entnahmen', withdrawal),
              TextField(
                controller: note,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notiz (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Speichern')),
        ],
      ),
    );

    if (saved != true) {
      for (final c in [opening, deposit, withdrawal, note]) {
        c.dispose();
      }
      return;
    }
    try {
      await _cashRepo.save(CashDay(
        day: current.day,
        openingCents: Money.parse(opening.text) ?? 0,
        depositCents: Money.parse(deposit.text) ?? 0,
        withdrawalCents: Money.parse(withdrawal.text) ?? 0,
        note: note.text.trim(),
      ));
      if (!mounted) return;
      _reloadCash();
      messenger.showSnackBar(const SnackBar(content: Text('Kassenwerte gespeichert')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Speichern fehlgeschlagen: $e')));
    } finally {
      for (final c in [opening, deposit, withdrawal, note]) {
        c.dispose();
      }
    }
  }

  Future<void> _resetDay(String day) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tageswerte zurücksetzen?'),
        content: Text('Kassenstart, Einlagen und Entnahmen für $day werden auf 0,00 € gesetzt. '
            'Die Verkäufe des Tages bleiben unberührt.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Zurücksetzen')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _cashRepo.reset(day);
      if (!mounted) return;
      _reloadCash();
      messenger.showSnackBar(const SnackBar(content: Text('Tageswerte zurückgesetzt')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  // ------------------------------------------------------------------ Export

  Future<void> _export(
    String kind,
    SalesSummary summary,
    Map<String, CashDay> cashDays,
    int drawerCents,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (kind == 'csv') {
        await ReportExport.shareCsv(
          period: _period,
          summary: summary,
          cashDays: cashDays,
          drawerCents: drawerCents,
        );
      } else {
        await ReportExport.sharePdf(
          period: _period,
          summary: summary,
          cashDays: cashDays,
          drawerCents: drawerCents,
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Export fehlgeschlagen: $e')));
    }
  }

  Future<void> _printDaySummary() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tagesabschluss drucken?'),
        content: Text('${_period.fromKey} wird auf dem Kassendrucker ausgegeben.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Drucken')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      messenger.showSnackBar(const SnackBar(content: Text('Druck startet…')));
      await ReceiptService().printDaySummary(_period.fromKey);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Tagesabschluss gedruckt')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Druckfehler: $e')));
    }
  }

  // ------------------------------------------------------------------ Aufbau

  Future<void> _pickDate() async {
    final first = _firstSaleDate ?? DateTime.now().subtract(const Duration(days: 365 * 3));
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _period.anchor.isAfter(now) ? now : _period.anchor,
      firstDate: first.isAfter(now) ? now : first,
      lastDate: now,
      helpText: 'Zeitraum wählen',
      locale: const Locale('de', 'DE'),
    );
    if (picked != null) _setPeriod(_period.withAnchor(picked));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canGoForward = !_period.shift(1).isFuture;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasse'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Zurück',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/admin');
            }
          },
        ),
      ),
      body: Column(
        children: [
          _periodBar(theme, canGoForward),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _salesRepo.streamSalesForRange(_period.fromKey, _period.toKey),
              builder: (context, salesSnap) {
                if (salesSnap.hasError) {
                  return _message(Icons.error_outline, 'Verkäufe konnten nicht geladen werden',
                      '${salesSnap.error}');
                }
                if (!salesSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final summary = SalesSummary.fromSales(salesSnap.data!);

                return FutureBuilder<Map<String, CashDay>>(
                  future: _cashFuture,
                  builder: (context, cashSnap) {
                    final cashDays = cashSnap.data ?? const <String, CashDay>{};
                    final opening = cashDays.values.fold(0, (a, d) => a + d.openingCents);
                    final deposit = cashDays.values.fold(0, (a, d) => a + d.depositCents);
                    final withdrawal = cashDays.values.fold(0, (a, d) => a + d.withdrawalCents);
                    final drawer = opening + summary.cashCents + deposit - withdrawal;

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      children: [
                        _kpiRow(theme, summary),
                        const SizedBox(height: 16),
                        _cashCard(theme, cashDays, summary, opening, deposit, withdrawal, drawer),
                        if (summary.days.length > 1) ...[
                          const SizedBox(height: 16),
                          _daysCard(theme, summary),
                        ],
                        const SizedBox(height: 16),
                        _itemsCard(theme, summary),
                        const SizedBox(height: 16),
                        _actions(summary, cashDays, drawer),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodBar(ThemeData theme, bool canGoForward) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          children: [
            SegmentedButton<PeriodKind>(
              segments: const [
                ButtonSegment(value: PeriodKind.day, label: Text('Tag')),
                ButtonSegment(value: PeriodKind.week, label: Text('Woche')),
                ButtonSegment(value: PeriodKind.month, label: Text('Monat')),
                ButtonSegment(value: PeriodKind.year, label: Text('Jahr')),
              ],
              selected: {_period.kind},
              onSelectionChanged: (s) => _setPeriod(_period.withKind(s.first)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Vorheriger Zeitraum',
                  onPressed: () => _setPeriod(_period.shift(-1)),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month, size: 18),
                    label: Text(
                      _period.label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: canGoForward ? 'Nächster Zeitraum' : 'Kein Zeitraum in der Zukunft',
                  onPressed: canGoForward ? () => _setPeriod(_period.shift(1)) : null,
                ),
              ],
            ),
          ],
        ),
      );

  Widget _kpiRow(ThemeData theme, SalesSummary s) {
    Widget tile(String label, String value, {bool strong = false}) => Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            color: strong ? theme.colorScheme.primaryContainer : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.labelSmall),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value,
                        style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: strong ? FontWeight.bold : FontWeight.w500)),
                  ),
                ],
              ),
            ),
          ),
        );

    return Row(children: [
      tile('Gesamt', Money.format(s.totalCents), strong: true),
      const SizedBox(width: 8),
      tile('Bar', Money.format(s.cashCents)),
      const SizedBox(width: 8),
      tile('Karte', Money.format(s.cardCents)),
      const SizedBox(width: 8),
      tile('Belege', '${s.receipts}'),
    ]);
  }

  Widget _cashCard(
    ThemeData theme,
    Map<String, CashDay> cashDays,
    SalesSummary summary,
    int opening,
    int deposit,
    int withdrawal,
    int drawer,
  ) {
    Widget row(String label, int cents, {bool negative = false, bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: bold ? theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold) : null),
              Text('${negative ? '− ' : ''}${Money.format(cents)}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        );

    final single = _period.isSingleDay;
    final day = cashDays[_period.fromKey] ?? CashDay.empty(_period.fromKey);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text('Kassenbestand',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold))),
                if (single)
                  TextButton.icon(
                    onPressed: () => _editCashDay(day),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Bearbeiten'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            row('Kassenstart', opening),
            row('Barumsatz', summary.cashCents),
            row('Einlagen', deposit),
            row('Entnahmen', withdrawal, negative: true),
            const Divider(),
            row('Kasseninhalt rechnerisch', drawer, bold: true),
            if (!single)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Summe über ${cashDays.length} erfasste ${cashDays.length == 1 ? 'Tag' : 'Tage'} '
                  'im Zeitraum. Zum Bearbeiten auf „Tag" wechseln.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (single && day.note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Notiz: ${day.note}', style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }

  Widget _daysCard(ThemeData theme, SalesSummary s) {
    final fmt = DateFormat('EEE, d. MMM', 'de_DE');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tage', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final d in s.days)
              InkWell(
                onTap: () => _setPeriod(ReportPeriod(PeriodKind.day, DateTime.parse(d.day))),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 120,
                          child: Text(fmt.format(DateTime.parse(d.day)),
                              style: theme.textTheme.bodyMedium)),
                      Expanded(
                          child: Text('${d.receipts} ${d.receipts == 1 ? 'Beleg' : 'Belege'}',
                              style: theme.textTheme.bodySmall)),
                      Text(Money.format(d.totalCents),
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _itemsCard(ThemeData theme, SalesSummary s) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                      child: Text('Verkäufe je Artikel',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold))),
                  Text('${s.itemCount} Artikel', style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 8),
              if (s.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('Keine Verkäufe in diesem Zeitraum.',
                      style: theme.textTheme.bodyMedium),
                )
              else
                for (final i in s.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        SizedBox(
                            width: 44,
                            child: Text('${i.qty}×',
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600))),
                        Expanded(child: Text(i.name, style: theme.textTheme.bodyMedium)),
                        Text(Money.format(i.totalCents), style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      );

  Widget _actions(SalesSummary summary, Map<String, CashDay> cashDays, int drawer) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: () => _export('pdf', summary, cashDays, drawer),
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('PDF teilen'),
          ),
          OutlinedButton.icon(
            onPressed: () => _export('csv', summary, cashDays, drawer),
            icon: const Icon(Icons.table_view),
            label: const Text('CSV teilen'),
          ),
          if (_period.isSingleDay) ...[
            OutlinedButton.icon(
              onPressed: _printDaySummary,
              icon: const Icon(Icons.print),
              label: const Text('Tagesabschluss drucken'),
            ),
            TextButton.icon(
              onPressed: () => _resetDay(_period.fromKey),
              icon: const Icon(Icons.restart_alt),
              label: const Text('Tageswerte zurücksetzen'),
            ),
          ],
        ],
      );

  Widget _message(IconData icon, String title, String detail) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(detail,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
}
