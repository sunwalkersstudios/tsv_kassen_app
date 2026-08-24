import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../util/bluetooth_printer_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/user_menu_button.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        actions: const [UserMenuButton()],
      ),
      body: ListView(
        children: [
          FutureBuilder<Map<String, String>?>(
            future: BluetoothPrinterService().loadSavedPrinter(),
            builder: (context, snapshot) {
              final isConfigured = snapshot.data != null;
              return ListTile(
                title: const Text('Bluetooth-Drucker (GOOJPRT PT-310) einstellen'),
                subtitle: Text(
                  isConfigured 
                    ? 'Verbunden: ${snapshot.data!['name']}'
                    : 'Bluetooth-Thermodrucker für Bons konfigurieren'
                ),
                leading: Icon(
                  Icons.bluetooth,
                  color: isConfigured ? Colors.blue : null,
                ),
                trailing: isConfigured 
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : const Icon(Icons.bluetooth_disabled),
                onTap: () async {
              final btService = BluetoothPrinterService();
              
              // Fordere alle benötigten Berechtigungen an
              Map<Permission, PermissionStatus> statuses = await [
                Permission.bluetoothScan,
                Permission.bluetoothConnect,
              ].request();
              
              // Prüfe ob alle Berechtigungen erteilt wurden
              bool allGranted = statuses.values.every((status) => status.isGranted);
              bool anyPermanentlyDenied = statuses.values.any((status) => status.isPermanentlyDenied);
              
              if (anyPermanentlyDenied) {
                if (!context.mounted) return;
                final openSettings = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Berechtigungen erforderlich'),
                    content: const Text(
                      'Bitte erlaube Bluetooth-Berechtigungen in den Einstellungen.'
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Abbrechen'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Einstellungen'),
                      ),
                    ],
                  ),
                );
                if (openSettings == true) {
                  await openAppSettings();
                }
                return;
              }
              
              if (!allGranted) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Bluetooth-Berechtigungen benötigt'),
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }

              if (!context.mounted) return;
              
              // Zeige Scan-Dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => const AlertDialog(
                  title: Text('Suche Bluetooth-Geräte...'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Bitte warten...'),
                    ],
                  ),
                ),
              );

              try {
                final devices = await btService.scanForDevices(timeout: const Duration(seconds: 8));
                
                // Schließe Scan-Dialog erst nachdem wir mounted geprüft haben
                if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).pop(); // Schließe Scan-Dialog
                }
                
                if (!context.mounted) return;
                
                if (devices.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Keine Bluetooth-Geräte gefunden')),
                  );
                  return;
                }

                // Warte kurz bevor nächster Dialog geöffnet wird
                await Future.delayed(const Duration(milliseconds: 300));
                
                if (!context.mounted) return;

                // Zeige Liste der gefundenen Geräte
                final selectedDevice = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Bluetooth-Drucker wählen'),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Gefundene Geräte:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Flexible(
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: devices.length,
                              itemBuilder: (context, index) {
                                final device = devices[index].device;
                                final name = device.platformName.isNotEmpty 
                                    ? device.platformName 
                                    : 'Unbekannt';
                                return Card(
                                  child: ListTile(
                                    leading: const Icon(Icons.bluetooth),
                                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(device.remoteId.str),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => Navigator.of(ctx).pop('${device.remoteId.str}|||$name'),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Abbrechen'),
                      ),
                    ],
                  ),
                );

                if (selectedDevice != null) {
                  final parts = selectedDevice.split('|||');
                  final address = parts[0];
                  final name = parts[1];
                  
                  await btService.savePrinter(address, name);
                  
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Bluetooth-Drucker gespeichert: $name')),
                  );
                }
              } catch (e) {
                // Schließe Scan-Dialog im Fehlerfall
                if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).pop();
                }
                
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Fehler: $e')),
                );
              }
            },
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.bluetooth),
                label: const Text('Bluetooth-Drucker Testdruck'),
                onPressed: () async {
                  try {
                    // Fordere Berechtigungen an
                    final status = await Permission.bluetoothConnect.request();
                    
                    if (status.isPermanentlyDenied) {
                      if (!context.mounted) return;
                      final openSettings = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Berechtigung erforderlich'),
                          content: const Text('Bitte erlaube Bluetooth in den Einstellungen.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Abbrechen'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Einstellungen'),
                            ),
                          ],
                        ),
                      );
                      if (openSettings == true) {
                        await openAppSettings();
                      }
                      return;
                    }
                    
                    if (!status.isGranted) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Bluetooth-Berechtigung benötigt')),
                        );
                      }
                      return;
                    }

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Verbinde mit Drucker...')),
                      );
                    }
                    
                    await BluetoothPrinterService().printTest();
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✓ Verbindung erfolgreich - Testdruck gesendet'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Fehler: $e')),
                      );
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
            title: const Text('Einstellungen'),
            subtitle: const Text('Bar und Küche zusammenlegen, weitere Optionen'),
            trailing: const Icon(Icons.settings),
            onTap: () => context.push('/admin/settings'),
          ),
          const Divider(),
          ListTile(
            title: const Text('Kasse / Tagesübersicht'),
            subtitle: const Text('Tagesumsatz, Barbestand, Artikelübersicht'),
            trailing: const Icon(Icons.point_of_sale),
            onTap: () => context.push('/cashier'),
          ),
          const Divider(),
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
            title: const Text('Speisen & Getränke'),
            subtitle: const Text('Menü und Artikel pflegen'),
            trailing: const Icon(Icons.restaurant_menu),
            onTap: () => context.push('/admin/menu'),
          ),
        ],
      ),
    );
  }
}
