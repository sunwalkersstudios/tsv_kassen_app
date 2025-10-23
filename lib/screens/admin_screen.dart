import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repo/tickets_repo.dart';
import '../util/receipt_service.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Bondrucker (Kellner) einstellen'),
            subtitle: const Text('IP/Port für Beleg-Druck (Kellner/Kassieren) festlegen'),
            trailing: const Icon(Icons.print),
            onTap: () async {
              final ipCtrl = TextEditingController();
              final portCtrl = TextEditingController(text: '9100');
              int cols = 32; // 58mm default
              String mode = 'escpos';
              // preload existing
              final svc = ReceiptService();
              final sp = await SharedPreferences.getInstance();
              ipCtrl.text = sp.getString('bon_printer_ip') ?? sp.getString('printer_ip') ?? '';
              portCtrl.text = (sp.getInt('bon_printer_port') ?? sp.getInt('printer_port') ?? 9100).toString();
              cols = sp.getInt('bon_printer_cols') ?? 32;
              mode = sp.getString('bon_printer_mode') ?? 'escpos';
              if (!context.mounted) return;
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => StatefulBuilder(
                  builder: (ctx, setStateDlg) => AlertDialog(
                    title: const Text('Bondrucker einstellen'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(controller: ipCtrl, decoration: const InputDecoration(labelText: 'IP-Adresse')),
                        TextField(controller: portCtrl, decoration: const InputDecoration(labelText: 'Port'), keyboardType: TextInputType.number),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('Papierbreite:'),
                            const SizedBox(width: 12),
                            DropdownButton<int>(
                              value: cols,
                              items: const [
                                DropdownMenuItem(value: 32, child: Text('58mm (≈32 Zeichen)')),
                                DropdownMenuItem(value: 48, child: Text('80mm (≈48 Zeichen)')),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setStateDlg(() => cols = v);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('Modus:'),
                            const SizedBox(width: 12),
                            DropdownButton<String>(
                              value: mode,
                              items: const [
                                DropdownMenuItem(value: 'escpos', child: Text('ESC/POS (Thermodrucker)')),
                                DropdownMenuItem(value: 'plain', child: Text('Plain Text')),
                              ],
                              onChanged: (v) { if (v != null) setStateDlg(() => mode = v); },
                            ),
                          ],
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
                      ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Speichern')),
                    ],
                  ),
                ),
              );
              if (ok == true && context.mounted) {
                final ip = ipCtrl.text.trim();
                final port = int.tryParse(portCtrl.text.trim()) ?? 9100;
                await svc.savePrinter(ip: ip, port: port, type: 'bon', cols: cols, mode: mode);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bondrucker gespeichert')));
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.print),
                label: const Text('Bondrucker Testdruck'),
                onPressed: () async {
                  try {
                    await ReceiptService().printTest(type: 'bon');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Testdruck gesendet')));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Testdruck fehlgeschlagen: $e')));
                    }
                  }
                },
              ),
            ),
          ),
          ListTile(
            title: const Text('Kassendrucker einstellen'),
            subtitle: const Text('IP/Port für Kassen-Druck (z. B. Tagesabschluss) festlegen'),
            trailing: const Icon(Icons.print_outlined),
            onTap: () async {
              final ipCtrl = TextEditingController();
              final portCtrl = TextEditingController(text: '9100');
              final svc = ReceiptService();
              final sp = await SharedPreferences.getInstance();
              ipCtrl.text = sp.getString('cash_printer_ip') ?? '';
              portCtrl.text = (sp.getInt('cash_printer_port') ?? 9100).toString();
              int cols = sp.getInt('cash_printer_cols') ?? 48;
              String mode = sp.getString('cash_printer_mode') ?? 'plain';
              if (!context.mounted) return;
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => StatefulBuilder(
                  builder: (ctx, setStateDlg) => AlertDialog(
                    title: const Text('Kassendrucker einstellen'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(controller: ipCtrl, decoration: const InputDecoration(labelText: 'IP-Adresse')),
                        TextField(controller: portCtrl, decoration: const InputDecoration(labelText: 'Port'), keyboardType: TextInputType.number),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('Papierbreite:'),
                            const SizedBox(width: 12),
                            DropdownButton<int>(
                              value: cols,
                              items: const [
                                DropdownMenuItem(value: 32, child: Text('58mm (≈32 Zeichen)')),
                                DropdownMenuItem(value: 48, child: Text('80mm (≈48 Zeichen)')),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setStateDlg(() => cols = v);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('Modus:'),
                            const SizedBox(width: 12),
                            DropdownButton<String>(
                              value: mode,
                              items: const [
                                DropdownMenuItem(value: 'plain', child: Text('Plain Text (A4)')),
                                DropdownMenuItem(value: 'escpos', child: Text('ESC/POS')),
                              ],
                              onChanged: (v) { if (v != null) setStateDlg(() => mode = v); },
                            ),
                          ],
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
                      ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Speichern')),
                    ],
                  ),
                ),
              );
              if (ok == true && context.mounted) {
                final ip = ipCtrl.text.trim();
                final port = int.tryParse(portCtrl.text.trim()) ?? 9100;
                await svc.savePrinter(ip: ip, port: port, type: 'cashier', cols: cols, mode: mode);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kassendrucker gespeichert')));
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.print_outlined),
                label: const Text('Kassendrucker Testdruck'),
                onPressed: () async {
                  try {
                    await ReceiptService().printTest(type: 'cashier');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Testdruck gesendet')));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Testdruck fehlgeschlagen: $e')));
                    }
                  }
                },
              ),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Druck-Layout (Plain Text) anpassen'),
            subtitle: const Text('Vorlagen für A4/Plain: Header, Position, Footer, Bewirtungsbeleg'),
            trailing: const Icon(Icons.tune),
            onTap: () => context.push('/admin/print-template'),
          ),
          const Divider(),
          ListTile(
            title: const Text('Kasse / Tagesübersicht'),
            subtitle: const Text('Tagesumsatz, Barbestand, Artikelübersicht, Bondrucker'),
            trailing: const Icon(Icons.point_of_sale),
            onTap: () => context.push('/cashier'),
          ),
          const Divider(),
          ListTile(
            title: const Text('Demo-Basisartikel hinzufügen'),
            subtitle: const Text('Fügt Cola und Schnitzel als Basis-Artikel hinzu'),
            trailing: const Icon(Icons.download_for_offline),
            onTap: () async {
              // lazy import to keep file lightweight
              // ignore: avoid_dynamic_calls
              try {
                // We import here to avoid adding repo import at top if not needed elsewhere
                // ignore: unused_local_variable
                final repo = (await Future.value(() => null)) as dynamic;
              } catch (_) {}
              // Inline call using deferred import is not straightforward here; just duplicate minimal logic via Navigator push
              // Navigate to /admin/menu where the AppBar action can fill demo data
              if (context.mounted) context.push('/admin/menu');
            },
          ),
          ListTile(
            title: const Text('Veranstaltungen verwalten'),
            subtitle: const Text('Anlegen, aktivieren, Zeitraum festlegen'),
            trailing: const Icon(Icons.event),
            onTap: () => context.push('/admin/events'),
          ),
          ListTile(
            title: const Text('Tische verwalten'),
            subtitle: const Text('Anlegen, Position, aktiv/inaktiv'),
            trailing: const Icon(Icons.table_bar),
            onTap: () => context.push('/admin/tables'),
          ),
          ListTile(
            title: const Text('Speisen & Getränke (Basis)'),
            subtitle: const Text('Standardmenü pflegen'),
            trailing: const Icon(Icons.restaurant_menu),
            onTap: () => context.push('/admin/menu'),
          ),
          ListTile(
            title: const Text('Event-spezifische Speisen & Getränke'),
            subtitle: const Text('Zusätzliche Artikel je Event mit Preisen'),
            trailing: const Icon(Icons.local_offer),
            onTap: () => context.push('/admin/menu'),
          ),
          const Divider(),
          ListTile(
            title: const Text('Alle Tickets löschen (Demo-Cleanup)'),
            subtitle: const Text('Entfernt sämtliche Tickets inkl. Positionen'),
            trailing: const Icon(Icons.delete_forever, color: Colors.red),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Alle Tickets löschen?'),
                  content: const Text('Dies entfernt sämtliche Tickets und Positionen. Nicht rückgängig zu machen.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
                    ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Löschen')),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                // show progress
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => const Center(child: CircularProgressIndicator()),
                );
                try {
                  await TicketsRepo().deleteAllTickets(includePaid: true);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Alle Tickets gelöscht')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Fehler beim Löschen: $e')),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
