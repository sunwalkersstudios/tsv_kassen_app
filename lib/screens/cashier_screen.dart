import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../repo/sales_repo.dart';
import '../util/receipt_service.dart';

class CashierScreen extends StatefulWidget {
  const CashierScreen({super.key});

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  String _day = DateFormat('yyyy-MM-dd').format(DateTime.now());
  double _openingCash = 0.0;
  double _deposit = 0.0; // Einlagen
  double _withdrawal = 0.0; // Entnahmen

  @override
  void initState() {
    super.initState();
    _loadOpening();
  }

  Future<void> _loadOpening() async {
    try {
      final sp = await SharedPreferences.getInstance();
      _openingCash = sp.getDouble('openingCash:$_day') ?? 0.0;
      _deposit = sp.getDouble('cashDeposit:$_day') ?? 0.0;
      _withdrawal = sp.getDouble('cashWithdrawal:$_day') ?? 0.0;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _saveOpening() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setDouble('openingCash:$_day', _openingCash);
    } catch (_) {}
  }

  Future<void> _saveDeposit() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setDouble('cashDeposit:$_day', _deposit);
    } catch (_) {}
  }

  Future<void> _saveWithdrawal() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setDouble('cashWithdrawal:$_day', _withdrawal);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final repo = SalesRepo();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasse / Tagesübersicht'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              // Ensure a way back to Admin main if opened directly
              context.go('/admin');
            }
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Tagesabschluss drucken',
            icon: const Icon(Icons.print),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Tagesabschluss drucken?'),
                  content: Text('Tag $_day wird auf dem Kassendrucker gedruckt.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
                    FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Drucken')),
                  ],
                ),
              );
              if (confirm != true) return;
              try {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Druck startet...')));
                await ReceiptService().printDaySummary(_day);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tagesabschluss gedruckt.')));
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Druckfehler: $e')));
              }
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'csv') {
                try {
                  final repo = SalesRepo();
                  final sales = await repo.fetchSalesForDay(_day);
                  // Aggregate for summary
                  double grandTotal = 0.0;
                  double cashTotal = 0.0;
                  double cardTotal = 0.0;
                  for (final s in sales) {
                    final pm = (s['paymentMethod'] ?? '').toString();
                    final saleTotal = (s['total'] as num?)?.toDouble() ?? 0.0;
                    grandTotal += saleTotal;
                    if (pm == 'cash') {
                      cashTotal += saleTotal;
                    } else if (pm == 'card') {
                      cardTotal += saleTotal;
                    }
                  }
                  final cashInDrawer = _openingCash + cashTotal + _deposit - _withdrawal;
                  final sb = StringBuffer();
                  // Summary block
                  sb.writeln('SUMMARY');
                  sb.writeln('day;openingCash;deposit;withdrawal;cashTotal;cardTotal;grandTotal;cashInDrawer');
                  sb.writeln('$_day;${_openingCash.toStringAsFixed(2)};${_deposit.toStringAsFixed(2)};${_withdrawal.toStringAsFixed(2)};${cashTotal.toStringAsFixed(2)};${cardTotal.toStringAsFixed(2)};${grandTotal.toStringAsFixed(2)};${cashInDrawer.toStringAsFixed(2)}');
                  sb.writeln('');
                  // Detail lines
                  sb.writeln('paidAt;ticketId;tableName;paymentMethod;itemName;qty;lineTotal;saleTotal');
                  for (final s in sales) {
                    final paidAt = (s['paidAt']?.toString() ?? '');
                    final ticketId = (s['ticketId'] ?? '').toString();
                    final tableName = ((s['tableName'] ?? s['tableId']) ?? '').toString();
                    final pm = (s['paymentMethod'] ?? '').toString();
                    final saleTotal = ((s['total'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2);
                    final items = (s['items'] as List?) ?? const [];
                    if (items.isEmpty) {
                      sb.writeln('$paidAt;$ticketId;$tableName;$pm;;;;$saleTotal');
                    } else {
                      for (final it in items) {
                        final name = (it['name'] ?? it['menuItemId']).toString();
                        final qty = (it['qty'] as num?)?.toInt() ?? 0;
                        final lineTotal = (it['lineTotal'] as num?)?.toDouble() ?? 0.0;
                        sb.writeln('$paidAt;$ticketId;$tableName;$pm;$name;$qty;${lineTotal.toStringAsFixed(2)};$saleTotal');
                      }
                    }
                  }
                  await Clipboard.setData(ClipboardData(text: sb.toString()));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV in Zwischenablage kopiert')));
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CSV-Export fehlgeschlagen: $e')));
                }
              } else if (value == 'reset-day') {
                try {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Tageswerte zurücksetzen?'),
                      content: Text('Setzt Kassenstart, Einlagen und Entnahmen für $_day auf 0,00.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
                        FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Zurücksetzen')),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  final sp = await SharedPreferences.getInstance();
                  await sp.remove('openingCash:$_day');
                  await sp.remove('cashDeposit:$_day');
                  await sp.remove('cashWithdrawal:$_day');
                  setState(() {
                    _openingCash = 0.0;
                    _deposit = 0.0;
                    _withdrawal = 0.0;
                  });
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tageswerte zurückgesetzt')));
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler beim Zurücksetzen: $e')));
                }
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'csv', child: Text('Export CSV (Zwischenablage)')),
              PopupMenuItem(value: 'reset-day', child: Text('Tageswerte zurücksetzen')),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: repo.streamSalesForDay(_day),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Fehler: ${snap.error}'));
          }
          final sales = snap.data ?? const [];
          // Aggregate
          final perItem = <String, Map<String, dynamic>>{}; // name -> {qty,total}
          double grandTotal = 0.0;
          double cashTotal = 0.0;
          double cardTotal = 0.0;
          for (final s in sales) {
            final items = (s['items'] as List?) ?? const [];
            final pm = (s['paymentMethod'] ?? 'cash').toString();
            final saleTotal = (s['total'] as num?)?.toDouble() ?? 0.0;
            grandTotal += saleTotal;
            if (pm == 'cash') {
              cashTotal += saleTotal;
            } else {
              cardTotal += saleTotal;
            }
            for (final it in items) {
              final name = (it['name'] ?? it['menuItemId']).toString();
              final qty = (it['qty'] as num?)?.toInt() ?? 0;
              final lineTotal = (it['lineTotal'] as num?)?.toDouble() ?? 0.0;
              final entry = perItem.putIfAbsent(name, () => {'qty': 0, 'total': 0.0});
              entry['qty'] = (entry['qty'] as int) + qty;
              entry['total'] = ((entry['total'] as double) + lineTotal);
            }
          }
          final currency = NumberFormat.simpleCurrency(locale: 'de_DE');
          final cashInDrawer = _openingCash + cashTotal + _deposit - _withdrawal;

          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Tag: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _day,
                        items: [
                          for (int i = 0; i < 7; i++)
                            DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(Duration(days: i)))
                        ].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                        onChanged: (v) async {
                          if (v == null) return;
                          setState(() => _day = v);
                          await _loadOpening();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Kassenstart: '),
                    SizedBox(
                      width: 120,
                      child: TextFormField(
                        initialValue: _openingCash.toStringAsFixed(2),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onFieldSubmitted: (v) {
                          final parsed = double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
                          setState(() => _openingCash = parsed);
                          _saveOpening();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text('Einlagen: '),
                    SizedBox(
                      width: 110,
                      child: TextFormField(
                        initialValue: _deposit.toStringAsFixed(2),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onFieldSubmitted: (v) {
                          final parsed = double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
                          setState(() => _deposit = parsed);
                          _saveDeposit();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text('Entnahmen: '),
                    SizedBox(
                      width: 110,
                      child: TextFormField(
                        initialValue: _withdrawal.toStringAsFixed(2),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onFieldSubmitted: (v) {
                          final parsed = double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
                          setState(() => _withdrawal = parsed);
                          _saveWithdrawal();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Kasseninhalt: ${currency.format(cashInDrawer)}'),
                const Divider(),
                Text('Umsatz gesamt: ${currency.format(grandTotal)}'),
                Text('Bar: ${currency.format(cashTotal)} • Karte: ${currency.format(cardTotal)}'),
                const SizedBox(height: 8),
                const Text('Verkäufe je Artikel', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Expanded(
                  child: ListView(
                    children: perItem.entries.map((e) {
                      final name = e.key;
                      final qty = e.value['qty'] as int;
                      final total = e.value['total'] as double;
                      return ListTile(
                        dense: true,
                        title: Text(name),
                        trailing: Text('${qty}x • ${currency.format(total)}'),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
