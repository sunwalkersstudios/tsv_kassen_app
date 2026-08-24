import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BluetoothPrinterService {
  static const String _printerAddressKey = 'bluetooth_printer_address';
  static const String _printerNameKey = 'bluetooth_printer_name';

  /// Scannt nach verfügbaren Bluetooth-Geräten
  Future<List<ScanResult>> scanForDevices({Duration timeout = const Duration(seconds: 10)}) async {
    final List<ScanResult> devices = [];
    final Set<String> seenAddresses = {};
    
    // Prüfe ob Bluetooth verfügbar ist
    if (await FlutterBluePlus.isSupported == false) {
      throw Exception('Bluetooth wird auf diesem Gerät nicht unterstützt');
    }

    try {
      // Füge bereits verbundene Geräte hinzu (z.B. gekoppelte Geräte)
      final connectedDevices = await FlutterBluePlus.connectedDevices;
      print('DEBUG: Verbundene Geräte: ${connectedDevices.length}');
      for (var device in connectedDevices) {
        final address = device.remoteId.str;
        final name = device.platformName;
        print('DEBUG: Verbundenes Gerät: $name ($address)');
        if (!seenAddresses.contains(address)) {
          seenAddresses.add(address);
          devices.add(ScanResult(device: device, advertisementData: AdvertisementData(
            advName: name,
            txPowerLevel: 0,
            appearance: 0,
            connectable: true,
            manufacturerData: {},
            serviceData: {},
            serviceUuids: [],
          ), rssi: 0, timeStamp: DateTime.now()));
        }
      }
    } catch (e) {
      print('DEBUG: Fehler beim Abrufen verbundener Geräte: $e');
    }

    // Starte Bluetooth-Scan
    print('DEBUG: Starte Bluetooth-Scan...');
    await FlutterBluePlus.startScan(timeout: timeout);

    // Sammle Scan-Ergebnisse (dedupliziert)
    final subscription = FlutterBluePlus.scanResults.listen((results) {
      print('DEBUG: Scan-Ergebnisse erhalten: ${results.length}');
      for (var result in results) {
        final address = result.device.remoteId.str;
        final name = result.device.platformName;
        print('DEBUG: Gescanntes Gerät: $name ($address)');
        if (!seenAddresses.contains(address)) {
          seenAddresses.add(address);
          devices.add(result);
        }
      }
    });

    // Warte auf Ende des Scans
    await Future.delayed(timeout);
    await FlutterBluePlus.stopScan();
    await subscription.cancel();

    print('DEBUG: Scan beendet. Gefundene Geräte: ${devices.length}');
    return devices;
  }

  /// Speichert den ausgewählten Drucker
  Future<void> savePrinter(String address, String name) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_printerAddressKey, address);
    await sp.setString(_printerNameKey, name);
  }

  /// Lädt gespeicherte Drucker-Informationen
  Future<Map<String, String>?> loadSavedPrinter() async {
    final sp = await SharedPreferences.getInstance();
    final address = sp.getString(_printerAddressKey);
    final name = sp.getString(_printerNameKey);
    
    if (address == null || name == null) return null;
    
    return {'address': address, 'name': name};
  }

  /// Verbindet mit einem Bluetooth-Drucker
  Future<BluetoothDevice> connectToPrinter(String deviceAddress) async {
    // Suche nach dem Gerät mit der angegebenen Adresse
    final devices = FlutterBluePlus.connectedDevices;
    
    for (var device in devices) {
      if (device.remoteId.str == deviceAddress) {
        // Gerät ist bereits verbunden
        return device;
      }
    }

    // Falls nicht verbunden, scanne nach dem Gerät
    BluetoothDevice? scannedDevice;
    
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    
    final subscription = FlutterBluePlus.scanResults.listen((results) {
      for (var result in results) {
        if (result.device.remoteId.str == deviceAddress) {
          scannedDevice = result.device;
          break;
        }
      }
    });

    await Future.delayed(const Duration(seconds: 5));
    await FlutterBluePlus.stopScan();
    await subscription.cancel();

    if (scannedDevice == null) {
      throw Exception('Drucker nicht gefunden');
    }

    // Verbinde mit dem Gerät - längerer Timeout für stabilere Verbindung
    print('DEBUG: Verbinde mit Drucker...');
    await scannedDevice!.connect(
      timeout: const Duration(seconds: 15),
      autoConnect: false, // Direkte Verbindung statt Auto-Connect
    );
    
    // Warte kurz bis Verbindung stabil ist
    await Future.delayed(const Duration(milliseconds: 500));
    print('DEBUG: Verbindung hergestellt');
    
    return scannedDevice!;
  }

  /// Sendet Daten an den Drucker
  Future<void> printData(BluetoothDevice device, List<int> data) async {
    // Entdecke Services
    final services = await device.discoverServices();
    
    BluetoothCharacteristic? writeCharacteristic;
    
    // Suche nach einem Schreib-Characteristic (typischerweise für Drucker)
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
          writeCharacteristic = characteristic;
          break;
        }
      }
      if (writeCharacteristic != null) break;
    }

    if (writeCharacteristic == null) {
      throw Exception('Keine Schreib-Characteristic gefunden');
    }

    // Sende Daten in kleineren Chunks für GOOJPRT PT-310
    const int chunkSize = 20;
    print('DEBUG: Sende ${data.length} Bytes in ${(data.length / chunkSize).ceil()} Chunks');
    
    for (int i = 0; i < data.length; i += chunkSize) {
      final end = (i + chunkSize < data.length) ? i + chunkSize : data.length;
      final chunk = data.sublist(i, end);
      
      if (writeCharacteristic.properties.writeWithoutResponse) {
        await writeCharacteristic.write(chunk, withoutResponse: true);
      } else {
        await writeCharacteristic.write(chunk, withoutResponse: false);
      }
      
      // Längere Verzögerung für stabilere Übertragung
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    // Warte bis alle Daten verarbeitet wurden
    await Future.delayed(const Duration(milliseconds: 500));
    print('DEBUG: Daten gesendet');
  }

  /// Trennt die Verbindung zum Drucker
  Future<void> disconnect(BluetoothDevice device) async {
    await device.disconnect();
  }

  /// Erstellt ESC/POS-Befehle für Thermodrucker
  List<int> createEscPosCommands(String text, {
    bool bold = false,
    bool center = false,
    bool cut = false,
  }) {
    final List<int> commands = [];
    
    // ESC @ - Initialize printer
    commands.addAll([27, 64]);
    
    // Textausrichtung
    if (center) {
      commands.addAll([27, 97, 1]); // ESC a 1 - Center
    } else {
      commands.addAll([27, 97, 0]); // ESC a 0 - Left align
    }
    
    // Fettdruck
    if (bold) {
      commands.addAll([27, 69, 1]); // ESC E 1 - Bold on
    }
    
    // Text (Latin-1 Encoding für deutsche Umlaute)
    commands.addAll(latin1.encode(text));
    
    // Fettdruck aus
    if (bold) {
      commands.addAll([27, 69, 0]); // ESC E 0 - Bold off
    }
    
    // Papier schneiden
    if (cut) {
      commands.addAll([10, 10, 10]); // 3x LF - Feed paper
      commands.addAll([29, 86, 66, 0]); // GS V 66 0 - Partial cut
    }
    
    return commands;
  }

  /// Testdruck für Bluetooth-Drucker
  Future<void> printTest() async {
    print('DEBUG: Starte Testdruck...');
    final printerInfo = await loadSavedPrinter();
    if (printerInfo == null) {
      throw Exception('Kein Bluetooth-Drucker konfiguriert');
    }

    print('DEBUG: Verbinde mit ${printerInfo['name']}...');
    final device = await connectToPrinter(printerInfo['address']!);
    
    try {
      final commands = <int>[];
      
      // ESC @ - Drucker initialisieren (wichtig!)
      commands.addAll([27, 64]);
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Einfacher Text ohne Formatierung für ersten Test
      commands.addAll(latin1.encode('================================\n'));
      commands.addAll(latin1.encode('        TSV KASSE\n'));
      commands.addAll(latin1.encode('      TESTDRUCK OK\n'));
      commands.addAll(latin1.encode('================================\n'));
      commands.addAll(latin1.encode('\n'));
      commands.addAll(latin1.encode('Verbindung: ERFOLGREICH\n'));
      commands.addAll(latin1.encode('Drucker: ${printerInfo['name']}\n'));
      commands.addAll(latin1.encode('\n'));
      commands.addAll(latin1.encode('Datum: ${DateTime.now().toString().substring(0, 16)}\n'));
      commands.addAll(latin1.encode('\n'));
      commands.addAll(latin1.encode('================================\n'));
      
      // Papier vorschub
      commands.addAll([10, 10, 10, 10, 10]); // 5x LF für sichtbares Ergebnis
      
      print('DEBUG: Sende ${commands.length} Bytes Druckdaten...');
      await printData(device, commands);
      print('DEBUG: Testdruck abgeschlossen');
    } finally {
      await disconnect(device);
    }
  }

  /// Extrem minimaler Raw-Test - sendet nur ASCII ohne ESC/POS
  /// Wenn das nicht druckt, ist der Drucker selbst defekt
  Future<void> printRawTest() async {
    final printerInfo = await loadSavedPrinter();
    if (printerInfo == null) {
      throw Exception('Kein Bluetooth-Drucker konfiguriert');
    }

    print('DEBUG: RAW TEST - Verbinde mit ${printerInfo['name']}...');
    final device = await connectToPrinter(printerInfo['address']!);
    
    try {
      // NUR ASCII-Text, keine ESC/POS Befehle überhaupt
      final text = 'HALLO TEST\nDRUCKER AKTIV\n\n\n\n';
      final commands = ascii.encode(text);
      
      print('DEBUG: RAW TEST - Sende ${commands.length} Bytes: ${commands.join(',')}');
      await printData(device, commands);
      print('DEBUG: RAW TEST - Abgeschlossen');
    } finally {
      await disconnect(device);
    }
  }

  /// Hilfsfunktion: Erstellt eine Trennlinie
  List<int> createHorizontalRule(int cols) {
    return latin1.encode('${'-' * cols}\n');
  }

  /// Hilfsfunktion: Text mit Links-Rechts-Ausrichtung
  List<int> createLeftRightText(String left, String right, int cols) {
    // Nutze 'EUR' statt '€' wegen Codepage
    right = right.replaceAll('€', 'EUR');
    
    final padding = cols - left.length - right.length;
    if (padding >= 1) {
      return latin1.encode('$left${' ' * padding}$right\n');
    } else {
      // Falls nicht genug Platz, drucke in zwei Zeilen
      final result = <int>[];
      result.addAll(latin1.encode('$left\n'));
      final rightPad = cols - right.length;
      if (rightPad > 0) {
        result.addAll(latin1.encode('${' ' * rightPad}$right\n'));
      } else {
        result.addAll(latin1.encode('$right\n'));
      }
      return result;
    }
  }
}
