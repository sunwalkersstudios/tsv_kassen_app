import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../util/bluetooth_printer_service.dart';

class AdminPrintTemplateScreen extends StatefulWidget {
  const AdminPrintTemplateScreen({super.key});

  @override
  State<AdminPrintTemplateScreen> createState() => _AdminPrintTemplateScreenState();
}

class _AdminPrintTemplateScreenState extends State<AdminPrintTemplateScreen> {
  final _headerCtrl = TextEditingController();
  final _itemCtrl = TextEditingController();
  final _footerCtrl = TextEditingController();
  final _hospCtrl = TextEditingController();
  
  // Bluetooth/Thermodrucker Vorlagen (72mm)
  final _btHeaderCtrl = TextEditingController();
  final _btItemCtrl = TextEditingController();
  final _btFooterCtrl = TextEditingController();
  final _btHospCtrl = TextEditingController();
  
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    
    // Plain Text (A4) Vorlagen
    _headerCtrl.text = sp.getString('cash_plain_header') ?? 'TSV Kasse\n{hr}\nTicket: {ticketId}\nTisch: {tableName}\nZeit: {date}\n{hr}';
    _itemCtrl.text = sp.getString('cash_plain_item') ?? '{qty}x {name}';
    _footerCtrl.text = sp.getString('cash_plain_footer') ?? '{hr}\nSUMME:{space}{total} EUR\nZahlung: {payment}\n';
    _hospCtrl.text = sp.getString('cash_plain_hospitality') ?? 'BEWIRTUNGSBELEG\n{hr}\nDatum/Uhrzeit: {date}\nOrt: ___________________________\nAnzahl Personen: ____________\nBewirtete Personen: __________\nAnlass/Grund: _______________\n{hr}\nSumme:{space}{total} EUR\nHinweis: Kein Ausweis der Umsatzsteuer\n gemäß § 19 UStG (Kleinunternehmerregelung).\n\nUnterschrift Bewirtender:______________\nUnterschrift Empfänger: ______________\n';
    
    // Bluetooth/Thermodrucker Vorlagen (57mm in 80mm Drucker, rechts verschoben)
    _btHeaderCtrl.text = sp.getString('bt_thermal_header') ?? 
      '            TSV KASSE\n'
      '            ========================\n'
      '            Ticket: {ticketId}\n'
      '            Tisch:  {tableName}\n'
      '            ========================\n'
      '            Zeit:   {date}\n'
      '            ========================\n';
    
    _btItemCtrl.text = sp.getString('bt_thermal_item') ?? '            {qty}x {name}';
    
    _btFooterCtrl.text = sp.getString('bt_thermal_footer') ?? 
      '            ========================\n'
      '            SUMME: {total} EUR\n'
      '            Zahlung: {payment}\n'
      '            ========================\n'
      '            Kein MwSt-Ausweis\n'
      '            gem. Par.19 UStG\n'
      '            \n'
      '            Vielen Dank!\n';
    
    _btHospCtrl.text = sp.getString('bt_thermal_hospitality') ?? 
      '            BEWIRTUNGSBELEG\n'
      '            ========================\n'
      '            Datum: {date}\n'
      '            \n'
      '            Ort:\n'
      '            ____________________\n'
      '            \n'
      '            Anzahl Personen:\n'
      '            ____________________\n'
      '            \n'
      '            Bewirtete:\n'
      '            ____________________\n'
      '            \n'
      '            Anlass/Grund:\n'
      '            ____________________\n'
      '            ========================\n'
      '            Summe: {total}\n'
      '            ========================\n'
      '            Kein MwSt-Ausweis\n'
      '            gem. Par.19 UStG\n'
      '            \n'
      '            Untersch. Bewirt.:\n'
      '            ____________________\n'
      '            \n'
      '            Untersch. Empf.:\n'
      '            ____________________\n';
    
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    // A4 Plain Text
    await sp.setString('cash_plain_header', _headerCtrl.text);
    await sp.setString('cash_plain_item', _itemCtrl.text);
    await sp.setString('cash_plain_footer', _footerCtrl.text);
    await sp.setString('cash_plain_hospitality', _hospCtrl.text);
    
    // Bluetooth Thermodrucker (72mm)
    await sp.setString('bt_thermal_header', _btHeaderCtrl.text);
    await sp.setString('bt_thermal_item', _btItemCtrl.text);
    await sp.setString('bt_thermal_footer', _btFooterCtrl.text);
    await sp.setString('bt_thermal_hospitality', _btHospCtrl.text);
  }
  
  Future<void> _printTestBluetooth() async {
    // Messenger vor dem ersten await greifen, damit der BuildContext
    // danach nicht mehr gebraucht wird.
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Speichere erst die aktuellen Vorlagen
      await _save();
      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(content: Text('Drucke Test-Bon mit aktueller Vorlage…')),
      );

      // Nutze die vorhandene BluetoothPrinterService printTest Methode
      final btService = BluetoothPrinterService();
      await btService.printTest();
      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(
          content: Text('✓ Test-Bon gedruckt'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Fehler beim Drucken: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Druck-Layout (Plain Text)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () async {
              await _save();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vorlagen gespeichert')));
              }
            },
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12),
              child: ListView(
                children: [
                  _helpCard(),
                  const SizedBox(height: 16),
                  
                  // Bluetooth Thermodrucker Vorlagen (57mm rechts verschoben)
                  const Text('Bluetooth-Thermodrucker (57mm in 80mm)', 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _section('Header (Thermodrucker)', _btHeaderCtrl,
                      hint: '57mm Papier rechts im 80mm Drucker (12 Leerzeichen Offset). Tokens: {ticketId}, {tableName}, {date}'),
                  _section('Positionszeile', _btItemCtrl,
                      singleLine: true, hint: 'z. B. {qty}x {name}'),
                  _section('Footer (mit §19 UStG)', _btFooterCtrl, 
                      hint: 'Tokens: {hr}, {total}, {payment}'),
                  _section('Bewirtungsbeleg (Thermodrucker)', _btHospCtrl,
                      hint: 'Tokens: {hr}, {date}, {total}'),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.print),
                      label: const Text('Test-Bon drucken (Bluetooth)'),
                      onPressed: _printTestBluetooth,
                    ),
                  ),
                  
                  const Divider(height: 32),
                  
                  // Plain Text A4 Vorlagen
                  const Text('A4-Drucker (Plain Text)', 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _section('Header (Plain Kassendrucker)', _headerCtrl,
                      hint: 'Mehrzeilig. Tokens: {hr}, {ticketId}, {tableName}, {date}'),
                  _section('Positionszeile (links)', _itemCtrl,
                      singleLine: true, hint: 'z. B. {qty}x {name}'),
                  _section('Footer', _footerCtrl, hint: 'Tokens: {hr}, {total}, {payment}, {space}'),
                  const Divider(),
                  _section('Bewirtungsbeleg (Plain)', _hospCtrl,
                      hint: 'Tokens: {hr}, {date}, {total}'),
                ],
              ),
            ),
    );
  }

  Widget _helpCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Platzhalter', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text('- {hr} = Trennlinie in aktueller Breite'),
            Text('- {space} = dynamischer Abstand bis zur rechten Spalte'),
            Text('- {ticketId}, {tableName}, {date}'),
            Text('- {qty}, {name}, {price}, {lineTotal}, {total}, {payment}'),
            SizedBox(height: 6),
            Text('Hinweis: Summen werden automatisch rechtsbündig ausgerichtet.'),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, TextEditingController ctrl, {bool singleLine = false, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: singleLine ? 1 : 6,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: hint,
          ),
          style: const TextStyle(fontFamily: 'monospace'),
        ),
      ],
    );
  }
}
