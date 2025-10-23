import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReceiptService {
  final _db = FirebaseFirestore.instance;

  /// Load printer configuration.
  /// type: 'bon' (default for Kellner-Belege) or 'cashier' (Kassendrucker).
  Future<Map<String, dynamic>> _loadPrinter({String type = 'bon'}) async {
    final sp = await SharedPreferences.getInstance();
    String ip;
    int port;
    int cols;
    String mode;
    if (type == 'cashier') {
      ip = sp.getString('cash_printer_ip') ?? '';
      port = sp.getInt('cash_printer_port') ?? 9100;
      cols = sp.getInt('cash_printer_cols') ?? 48; // default 80mm ≈ 48 chars
      mode = sp.getString('cash_printer_mode') ?? 'plain'; // plain text by default for A4
    } else {
      ip = sp.getString('bon_printer_ip') ?? '';
      port = sp.getInt('bon_printer_port') ?? 9100;
      // Backwards compatibility fallback
      if (ip.isEmpty) ip = sp.getString('printer_ip') ?? '';
      if ((sp.getInt('bon_printer_port') ?? 0) == 0) {
        final legacy = sp.getInt('printer_port');
        if (legacy != null) port = legacy;
      }
      cols = sp.getInt('bon_printer_cols') ?? 32; // default 58mm ≈ 32 chars
      mode = sp.getString('bon_printer_mode') ?? 'escpos';
    }
    return {'ip': ip, 'port': port, 'cols': cols, 'mode': mode};
  }

  /// Save printer configuration.
  /// type: 'bon' for Kellner-Belege or 'cashier' for Kassendrucker.
  Future<void> savePrinter({required String ip, int port = 9100, String type = 'bon', int? cols, String? mode}) async {
    final sp = await SharedPreferences.getInstance();
    if (type == 'cashier') {
      await sp.setString('cash_printer_ip', ip);
      await sp.setInt('cash_printer_port', port);
      if (cols != null) await sp.setInt('cash_printer_cols', cols);
      if (mode != null) await sp.setString('cash_printer_mode', mode);
    } else {
      await sp.setString('bon_printer_ip', ip);
      await sp.setInt('bon_printer_port', port);
      if (cols != null) await sp.setInt('bon_printer_cols', cols);
      if (mode != null) await sp.setString('bon_printer_mode', mode);
    }
  }

  // Helpers for formatting to a fixed character width
  List<int> _hr(int cols) => latin1.encode('${'-' * cols}\n');
  List<int> _text(String s) => latin1.encode('$s\n');

  void _addLeftRight(List<int> esc, String left, String right, int cols) {
    // Use 'EUR' instead of '€' to avoid codepage issues and width mismatch
    right = right.replaceAll('€', 'EUR');
    final maxLeft = (cols - right.length - 1).clamp(1, cols);
    // Split left into chunks
    final chunks = <String>[];
    var remaining = left;
    while (remaining.isNotEmpty) {
      if (remaining.length <= maxLeft) {
        chunks.add(remaining);
        break;
      } else {
        chunks.add(remaining.substring(0, maxLeft));
        remaining = remaining.substring(maxLeft);
      }
    }
    if (chunks.isEmpty) {
      // just print right aligned
      final pad = cols - right.length;
      esc.addAll(_text('${' ' * pad}$right'));
      return;
    }
    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      final isLast = i == chunks.length - 1;
      if (isLast) {
        final pad = cols - chunk.length - right.length;
        if (pad >= 1) {
          esc.addAll(_text('$chunk${' ' * pad}$right'));
        } else {
          // Not enough space -> print amount on next line right aligned
          esc.addAll(_text(chunk));
          final pad2 = cols - right.length;
          esc.addAll(_text('${' ' * pad2}$right'));
        }
      } else {
        esc.addAll(_text(chunk));
      }
    }
  }

  // String builder variant for plain-text printers (A4)
  void _addLeftRightStr(StringBuffer sb, String left, String right, int cols) {
    right = right.replaceAll('€', 'EUR');
    final maxLeft = (cols - right.length - 1).clamp(1, cols);
    final chunks = <String>[];
    var remaining = left;
    while (remaining.isNotEmpty) {
      if (remaining.length <= maxLeft) {
        chunks.add(remaining);
        break;
      } else {
        chunks.add(remaining.substring(0, maxLeft));
        remaining = remaining.substring(maxLeft);
      }
    }
    if (chunks.isEmpty) {
      final pad = cols - right.length;
      sb.writeln('${' ' * pad}$right');
      return;
    }
    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      final isLast = i == chunks.length - 1;
      if (isLast) {
        final pad = cols - chunk.length - right.length;
        if (pad >= 1) {
          sb.writeln('$chunk${' ' * pad}$right');
        } else {
          sb.writeln(chunk);
          final pad2 = cols - right.length;
          sb.writeln('${' ' * pad2}$right');
        }
      } else {
        sb.writeln(chunk);
      }
    }
  }

  Future<Map<String, String>> _loadPlainTemplateSet(String type) async {
    // type: 'cashier' or 'bon'
    final sp = await SharedPreferences.getInstance();
    final prefix = type == 'cashier' ? 'cash_plain_' : 'bon_plain_';
    return {
      'header': sp.getString('${prefix}header') ?? 'TSV Kasse\n{hr}\nTicket: {ticketId}\nTisch: {tableName}\nZeit: {date}\n{hr}',
      'item': sp.getString('${prefix}item') ?? '{qty}x {name}',
      'footer': sp.getString('${prefix}footer') ?? '{hr}\nSUMME:{space}{total} EUR\nZahlung: {payment}\n',
      'hospitality': sp.getString('${prefix}hospitality') ?? 'BEWIRTUNGSBELEG\n{hr}\nDatum/Uhrzeit: {date}\nOrt: ___________________________\nAnzahl Personen: ____________\nBewirtete Personen: __________\nAnlass/Grund: _______________\n{hr}\nSumme:{space}{total} EUR\nHinweis: Kein Ausweis der Umsatzsteuer\n gemäß § 19 UStG (Kleinunternehmerregelung).\n\nUnterschrift Bewirtender:______________\nUnterschrift Empfänger: ______________\n',
    };
  }

  String _replaceVars(String src, Map<String, String> vars, int cols) {
    String out = src;
    vars.forEach((k, v) {
      out = out.replaceAll('{$k}', v);
    });
    out = out.replaceAll('{hr}', '-' * cols);
    // {space} is handled when aligning left/right, here we just remove it in standalone contexts
    out = out.replaceAll('{space}', ' ');
    return out;
  }

  Future<void> printSale(String id, {String printerType = 'bon'}) async {
    final printerCfg = await _loadPrinter(type: printerType);
    final ip = (printerCfg['ip'] as String).trim();
    final port = (printerCfg['port'] as int);
    final cols = (printerCfg['cols'] as int);
    final mode = (printerCfg['mode'] as String);
    if (ip.isEmpty) {
      throw Exception('Kein Bondrucker konfiguriert');
    }

    // Load sale doc: first try as saleId, then fallback to latest sale for ticketId
    Map<String, dynamic>? s;
    var saleDoc = await _db.collection('sales').doc(id).get();
    if (saleDoc.exists) {
      s = saleDoc.data();
    } else {
      final q = await _db
          .collection('sales')
          .where('ticketId', isEqualTo: id)
          .orderBy('paidAt', descending: true)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        s = q.docs.first.data();
      }
    }
    if (s == null) throw Exception('Kein Verkaufsbeleg gefunden');
    final items = (s['items'] as List?) ?? const [];

    if (mode == 'plain') {
      final tpls = await _loadPlainTemplateSet(printerType);
      // Plain text output for A4 printers (no ESC/POS). Use CRLF.
      final sb = StringBuffer();
      final header = _replaceVars(tpls['header']!, {
        'ticketId': (s['ticketId'] ?? '').toString(),
        'tableName': ((s['tableName'] ?? s['tableId']) ?? '').toString(),
        'date': ((s['paidAt'] as Timestamp?)?.toDate().toString()) ?? '',
      }, cols);
      for (final line in header.split('\n')) {
        sb.writeln(line);
      }
      for (final it in items) {
        final name = (it['name'] ?? it['menuItemId']).toString();
        final qty = (it['qty'] as num?)?.toInt() ?? 0;
        final price = (it['price'] as num?)?.toDouble() ?? 0.0;
        final totalLine = (it['lineTotal'] as num?)?.toDouble() ?? (price * qty);
        final line = tpls['item']!
            .replaceAll('{qty}', qty.toString())
            .replaceAll('{name}', name)
            .replaceAll('{price}', price.toStringAsFixed(2))
            .replaceAll('{lineTotal}', totalLine.toStringAsFixed(2));
        final amt = '${totalLine.toStringAsFixed(2)} EUR';
        _addLeftRightStr(sb, line, amt, cols);
      }
      final footer = _replaceVars(tpls['footer']!, {
        'total': ((s['total'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2),
        'payment': (s['paymentMethod'] ?? 'Bar').toString(),
      }, cols);
      // In footer we also keep alignment for SUMME if template uses it implicitly
      // Split footer lines and write them
      for (final line in footer.split('\n')) {
        if (line.contains('SUMME:') && line.contains('{space}')) {
          // legacy support; already handled in template replacement above
          final total = ((s['total'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2) + ' EUR';
          _addLeftRightStr(sb, 'SUMME:', total, cols);
        } else {
          sb.writeln(line);
        }
      }
      final bytes = latin1.encode(sb.toString().replaceAll('\n', '\r\n'));
      final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 8));
      socket.add(bytes);
      await socket.flush();
      await socket.close();
    } else {
      // ESC/POS output
      final esc = <int>[27, 64]; // ESC @ (initialize)
      esc.addAll([27, 97, 1]); // center
      esc.addAll(latin1.encode('TSV Kasse\n'));
      esc.addAll([27, 97, 0]); // left
      esc.addAll(_hr(cols));
      esc.addAll(_text('Ticket: ${s['ticketId'] ?? ''}'));
      final tableName = (s['tableName'] ?? s['tableId'] ?? '').toString();
      if (tableName.isNotEmpty) esc.addAll(_text('Tisch: $tableName'));
      final paidAt = (s['paidAt'] as Timestamp?)?.toDate();
      if (paidAt != null) esc.addAll(_text('Zeit: $paidAt'));
      esc.addAll(_hr(cols));
      for (final it in items) {
        final name = (it['name'] ?? it['menuItemId']).toString();
        final qty = (it['qty'] as num?)?.toInt() ?? 0;
        final price = (it['price'] as num?)?.toDouble() ?? 0.0;
        final totalLine = (it['lineTotal'] as num?)?.toDouble() ?? (price * qty);
        final line = '${qty}x $name';
        final amt = '${totalLine.toStringAsFixed(2)} EUR';
        _addLeftRight(esc, line, amt, cols);
      }
      esc.addAll(_hr(cols));
      final total = (s['total'] as num?)?.toDouble() ?? 0.0;
      _addLeftRight(esc, 'SUMME:', '${total.toStringAsFixed(2)} EUR', cols);
      esc.addAll(_text('Zahlung: Bar'));
      esc.addAll(_text(''));
      esc.addAll([29, 86, 66, 0]); // cut
      final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 8));
      socket.add(esc);
      await socket.flush();
      await socket.close();
    }
  }

  Future<void> printHospitalityReceipt(
    String id,
  ) async {
    // Use cashier printer
    final printerCfg = await _loadPrinter(type: 'cashier');
    final ip = (printerCfg['ip'] as String).trim();
    final port = (printerCfg['port'] as int);
    final cols = (printerCfg['cols'] as int);
    final mode = (printerCfg['mode'] as String);
    if (ip.isEmpty) {
      throw Exception('Kein Kassendrucker konfiguriert');
    }

    // Load sale (id may be saleId or ticketId)
    Map<String, dynamic>? s;
    var saleDoc = await _db.collection('sales').doc(id).get();
    if (saleDoc.exists) {
      s = saleDoc.data();
    } else {
      final q = await _db
          .collection('sales')
          .where('ticketId', isEqualTo: id)
          .orderBy('paidAt', descending: true)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        s = q.docs.first.data();
      }
    }
    if (s == null) throw Exception('Kein Verkaufsbeleg gefunden');

  final total = (s['total'] as num?)?.toDouble() ?? 0.0;
    final paidAt = (s['paidAt'] as Timestamp?)?.toDate();
    final ts = paidAt?.toString() ?? DateTime.now().toString();

    if (mode == 'plain') {
      final tpls = await _loadPlainTemplateSet('cashier');
      final sb = StringBuffer();
      final body = _replaceVars(tpls['hospitality']!, {
        'date': ts,
        'total': total.toStringAsFixed(2),
      }, cols);
      for (final line in body.split('\n')) {
        if (line.contains('Summe:') && line.contains('{space}')) {
          _addLeftRightStr(sb, 'Summe:', '${total.toStringAsFixed(2)} EUR', cols);
        } else {
          sb.writeln(line);
        }
      }
      final bytes = latin1.encode(sb.toString().replaceAll('\n', '\r\n'));
      final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 8));
      socket.add(bytes);
      await socket.flush();
      await socket.close();
    } else {
      final esc = <int>[27, 64]; // init
      esc.addAll([27, 97, 1]);
      esc.addAll(latin1.encode('BEWIRTUNGSBELEG\n'));
      esc.addAll([27, 97, 0]);
      esc.addAll(_hr(cols));
      esc.addAll(_text('Datum/Uhrzeit: $ts'));
      esc.addAll(latin1.encode('Ort: ___________________________\n'));
      esc.addAll(latin1.encode('Anzahl Personen: ____________\n'));
      esc.addAll(latin1.encode('Bewirtete Personen: __________\n'));
      esc.addAll(latin1.encode('Anlass/Grund: _______________\n'));
      esc.addAll(_hr(cols));
      _addLeftRight(esc, 'Summe:', '${total.toStringAsFixed(2)} EUR', cols);
      esc.addAll(latin1.encode('Hinweis: Kein Ausweis der Umsatzsteuer\n'));
      esc.addAll(latin1.encode('gemäß § 19 UStG (Kleinunternehmerregelung).\n'));
      esc.addAll(latin1.encode('\n'));
      esc.addAll(latin1.encode('Unterschrift Bewirtender:______________\n'));
      esc.addAll(latin1.encode('Unterschrift Empfänger: ______________\n'));
      esc.addAll(latin1.encode('\n\n'));
      esc.addAll([29, 86, 66, 0]); // cut
      final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 8));
      socket.add(esc);
      await socket.flush();
      await socket.close();
    }
  }

  /// Send a small test receipt to verify connectivity and paper output.
  Future<void> printTest({String type = 'bon'}) async {
    final cfg = await _loadPrinter(type: type);
    final ip = (cfg['ip'] as String).trim();
    final port = (cfg['port'] as int);
    final cols = (cfg['cols'] as int);
    final mode = (cfg['mode'] as String);
    if (ip.isEmpty) throw Exception(type == 'cashier' ? 'Kein Kassendrucker konfiguriert' : 'Kein Bondrucker konfiguriert');

    if (mode == 'plain') {
      final sb = StringBuffer();
      sb.writeln('TSV Kasse');
      sb.writeln(type == 'cashier' ? 'Kassendrucker Testdruck' : 'Bondrucker Testdruck');
      sb.writeln('-' * cols);
      sb.writeln('Wenn du diesen Text siehst,');
      sb.writeln('funktioniert die Verbindung.');
  sb.writeln('');
  sb.writeln('Unterschrift Betreiber: _______________');
  sb.writeln('Unterschrift Kassenprüfer: ____________');
      final bytes = latin1.encode(sb.toString().replaceAll('\n', '\r\n'));
      final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 8));
      socket.add(bytes);
      await socket.flush();
      await socket.close();
    } else {
      final esc = <int>[27, 64]; // ESC @
      esc.addAll([27, 97, 1]); // center
      esc.addAll(latin1.encode('TSV Kasse\n'));
      esc.addAll(latin1.encode(type == 'cashier' ? 'Kassendrucker Testdruck\n' : 'Bondrucker Testdruck\n'));
      esc.addAll([27, 97, 0]); // left
      esc.addAll(_hr(cols));
      esc.addAll(_text('Wenn du diesen Text siehst,'));
      esc.addAll(_text('funktioniert die Verbindung.'));
  esc.addAll(_text(''));
  esc.addAll(latin1.encode('Unterschrift Betreiber: _______________\n'));
  esc.addAll(latin1.encode('Unterschrift Kassenprüfer: ____________\n'));
      esc.addAll([29, 86, 66, 0]); // cut
      final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 8));
      socket.add(esc);
      await socket.flush();
      await socket.close();
    }
  }

  Future<void> printDaySummary(String day) async {
    // Use cashier printer
    final printerCfg = await _loadPrinter(type: 'cashier');
    final ip = (printerCfg['ip'] as String).trim();
    final port = (printerCfg['port'] as int);
    final cols = (printerCfg['cols'] as int);
    final mode = (printerCfg['mode'] as String);
    if (ip.isEmpty) {
      throw Exception('Kein Kassendrucker konfiguriert');
    }

    // Load sales for the day
    final snap = await _db.collection('sales').where('day', isEqualTo: day).get();
    final sales = snap.docs.map((d) => d.data()).toList();

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

    // Opening cash and adjustments
    double openingCash = 0.0;
    double deposit = 0.0;
    double withdrawal = 0.0;
    try {
      final sp = await SharedPreferences.getInstance();
      openingCash = sp.getDouble('openingCash:$day') ?? 0.0;
      deposit = sp.getDouble('cashDeposit:$day') ?? 0.0;
      withdrawal = sp.getDouble('cashWithdrawal:$day') ?? 0.0;
    } catch (_) {}
    final cashInDrawer = openingCash + cashTotal + deposit - withdrawal;

    if (mode == 'plain') {
      final sb = StringBuffer();
      sb.writeln('Tagesabschluss $day');
      sb.writeln('-' * cols);
      _addLeftRightStr(sb, 'Umsatz gesamt:', '${grandTotal.toStringAsFixed(2)} EUR', cols);
      _addLeftRightStr(sb, 'Bar:', '${cashTotal.toStringAsFixed(2)} EUR', cols);
      _addLeftRightStr(sb, 'Karte:', '${cardTotal.toStringAsFixed(2)} EUR', cols);
      sb.writeln('');
      _addLeftRightStr(sb, 'Kassenstart:', '${openingCash.toStringAsFixed(2)} EUR', cols);
  _addLeftRightStr(sb, 'Einlagen:', '${deposit.toStringAsFixed(2)} EUR', cols);
  _addLeftRightStr(sb, 'Entnahmen:', '${withdrawal.toStringAsFixed(2)} EUR', cols);
  _addLeftRightStr(sb, 'Kasseninhalt:', '${cashInDrawer.toStringAsFixed(2)} EUR', cols);
      sb.writeln('-' * cols);
      sb.writeln('Verkäufe je Artikel');
      final sorted = perItem.entries.toList()
        ..sort((a, b) => (b.value['total'] as double).compareTo(a.value['total'] as double));
      for (final e in sorted) {
        final name = e.key;
        final qty = e.value['qty'] as int;
        final total = (e.value['total'] as double);
        _addLeftRightStr(sb, '$name  ${qty}x', '${total.toStringAsFixed(2)} EUR', cols);
      }
      sb.writeln('');
      final bytes = latin1.encode(sb.toString().replaceAll('\n', '\r\n'));
      final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 8));
      socket.add(bytes);
      await socket.flush();
      await socket.close();
    } else {
      final esc = <int>[27, 64]; // init
      esc.addAll([27, 97, 1]);
      esc.addAll(latin1.encode('Tagesabschluss $day\n'));
      esc.addAll([27, 97, 0]);
      esc.addAll(_hr(cols));
      _addLeftRight(esc, 'Umsatz gesamt:', '${grandTotal.toStringAsFixed(2)} EUR', cols);
      _addLeftRight(esc, 'Bar:', '${cashTotal.toStringAsFixed(2)} EUR', cols);
      _addLeftRight(esc, 'Karte:', '${cardTotal.toStringAsFixed(2)} EUR', cols);
      esc.addAll(_text(''));
      _addLeftRight(esc, 'Kassenstart:', '${openingCash.toStringAsFixed(2)} EUR', cols);
  _addLeftRight(esc, 'Einlagen:', '${deposit.toStringAsFixed(2)} EUR', cols);
  _addLeftRight(esc, 'Entnahmen:', '${withdrawal.toStringAsFixed(2)} EUR', cols);
  _addLeftRight(esc, 'Kasseninhalt:', '${cashInDrawer.toStringAsFixed(2)} EUR', cols);
      esc.addAll(_hr(cols));
      esc.addAll(_text('Verkäufe je Artikel'));
      final sorted = perItem.entries.toList()
        ..sort((a, b) => (b.value['total'] as double).compareTo(a.value['total'] as double));
      for (final e in sorted) {
        final name = e.key;
        final qty = e.value['qty'] as int;
        final total = (e.value['total'] as double);
        _addLeftRight(esc, '$name  ${qty}x', '${total.toStringAsFixed(2)} EUR', cols);
      }
      esc.addAll(_text(''));
      esc.addAll([29, 86, 66, 0]); // cut
      final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 8));
      socket.add(esc);
      await socket.flush();
      await socket.close();
    }
  }
}
