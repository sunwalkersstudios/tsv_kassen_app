import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    _headerCtrl.text = sp.getString('cash_plain_header') ?? 'TSV Kasse\n{hr}\nTicket: {ticketId}\nTisch: {tableName}\nZeit: {date}\n{hr}';
    _itemCtrl.text = sp.getString('cash_plain_item') ?? '{qty}x {name}';
    _footerCtrl.text = sp.getString('cash_plain_footer') ?? '{hr}\nSUMME:{space}{total} EUR\nZahlung: {payment}\n';
    _hospCtrl.text = sp.getString('cash_plain_hospitality') ?? 'BEWIRTUNGSBELEG\n{hr}\nDatum/Uhrzeit: {date}\nOrt: ___________________________\nAnzahl Personen: ____________\nBewirtete Personen: __________\nAnlass/Grund: _______________\n{hr}\nSumme:{space}{total} EUR\nHinweis: Kein Ausweis der Umsatzsteuer\n gemäß § 19 UStG (Kleinunternehmerregelung).\n\nUnterschrift Bewirtender:______________\nUnterschrift Empfänger: ______________\n';
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('cash_plain_header', _headerCtrl.text);
    await sp.setString('cash_plain_item', _itemCtrl.text);
    await sp.setString('cash_plain_footer', _footerCtrl.text);
    await sp.setString('cash_plain_hospitality', _hospCtrl.text);
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
