import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../repo/device_repo.dart';

/// Freigeschaltete Geraete verwalten.
///
/// Auf einem freigeschalteten Geraet melden sich Kellner, Kueche und Bar durch
/// Tippen auf ihren Namen an - ohne Passwort. Adminkonten erscheinen dort nie
/// und brauchen weiterhin E-Mail und Passwort.
///
/// Das Geraet erhaelt beim Freischalten ein langes Zufallsgeheimnis, das nur
/// lokal liegt; in der Datenbank steht davon bloss eine Pruefsumme. Geht ein
/// Tablet verloren, wird die Freischaltung hier widerrufen - danach zeigt es
/// nur noch die Passwortmaske.
class AdminDevicesScreen extends StatefulWidget {
  const AdminDevicesScreen({super.key});

  @override
  State<AdminDevicesScreen> createState() => _AdminDevicesScreenState();
}

class _AdminDevicesScreenState extends State<AdminDevicesScreen> {
  final _repo = DeviceRepo();

  List<Map<String, dynamic>>? _geraete;
  String? _fehler;
  bool _laedt = false;
  bool _diesesFreigeschaltet = false;
  String? _diesesLabel;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    setState(() {
      _laedt = true;
      _fehler = null;
    });
    try {
      final liste = await _repo.listDevices();
      final registriert = await _repo.isRegistered();
      final label = await _repo.label();
      if (!mounted) return;
      setState(() {
        _geraete = liste;
        _diesesFreigeschaltet = registriert;
        _diesesLabel = label;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _fehler = '$e');
    } finally {
      if (mounted) setState(() => _laedt = false);
    }
  }

  Future<void> _freischalten() async {
    final ctrl = TextEditingController(text: 'Tablet Theke');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dieses Gerät freischalten'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Danach kann sich das Personal hier durch Tippen auf den Namen '
              'anmelden, ohne Passwort. Adminkonten bleiben ausgenommen.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Name des Geräts',
                helperText: 'Damit es später wiedererkennbar ist',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Freischalten')),
        ],
      ),
    );
    final label = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true) return;
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _repo.register(label.isEmpty ? 'Unbenanntes Gerät' : label);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Gerät freigeschaltet')));
      await _laden();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Freischalten fehlgeschlagen: $e')));
    }
  }

  Future<void> _widerrufen(Map<String, dynamic> g) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Freischaltung widerrufen?'),
        content: Text(
          '„${g['label']}“ kann sich danach nicht mehr per Namensauswahl anmelden. '
          'Angemeldete Sitzungen laufen weiter, bis sich jemand abmeldet.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Widerrufen')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.revoke((g['id'] ?? '').toString());
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Freischaltung widerrufen')));
      await _laden();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  String _zeit(String? iso) {
    if (iso == null) return 'nie';
    final d = DateTime.tryParse(iso);
    if (d == null) return 'nie';
    return DateFormat('d. MMM yyyy, HH:mm', 'de_DE').format(d.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Geräte'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Neu laden',
            onPressed: _laedt ? null : _laden,
          ),
        ],
      ),
      body: _laedt && _geraete == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: _diesesFreigeschaltet ? cs.secondaryContainer : cs.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _diesesFreigeschaltet ? cs.secondary : cs.outlineVariant),
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _diesesFreigeschaltet ? Icons.verified_user : Icons.phonelink_lock,
                            color: _diesesFreigeschaltet ? cs.secondary : cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _diesesFreigeschaltet
                                  ? 'Dieses Gerät ist freigeschaltet'
                                  : 'Dieses Gerät ist nicht freigeschaltet',
                              style: t.textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _diesesFreigeschaltet
                            ? 'Angemeldet als „${_diesesLabel ?? '—'}“. Das Personal meldet '
                                'sich hier ohne Passwort an.'
                            : 'Ohne Freischaltung zeigt dieses Gerät nur die Passwortmaske.',
                        style: t.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 14),
                      if (!_diesesFreigeschaltet)
                        FilledButton.icon(
                          onPressed: _freischalten,
                          icon: const Icon(Icons.add_moderator),
                          label: const Text('Dieses Gerät freischalten'),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: () async {
                            await _repo.forgetLocally();
                            await _laden();
                          },
                          icon: const Icon(Icons.link_off),
                          label: const Text('Freischaltung von diesem Gerät entfernen'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('ALLE GERÄTE', style: t.textTheme.labelSmall),
                const SizedBox(height: 8),
                if (_fehler != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('Liste nicht ladbar: $_fehler', style: t.textTheme.bodySmall),
                  )
                else if ((_geraete ?? const []).isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('Noch kein Gerät freigeschaltet.', style: t.textTheme.bodyMedium),
                  )
                else
                  for (final g in _geraete!)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: Icon(
                          g['disabled'] == true ? Icons.phonelink_erase : Icons.tablet_android,
                          color: g['disabled'] == true ? cs.error : cs.primary,
                        ),
                        title: Text((g['label'] ?? '').toString()),
                        subtitle: Text(
                          g['disabled'] == true
                              ? 'Widerrufen'
                              : 'Zuletzt benutzt: ${_zeit(g['lastUsed'] as String?)}',
                        ),
                        trailing: g['disabled'] == true
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.block),
                                tooltip: 'Freischaltung widerrufen',
                                onPressed: () => _widerrufen(g),
                              ),
                      ),
                    ),
              ],
            ),
    );
  }
}
