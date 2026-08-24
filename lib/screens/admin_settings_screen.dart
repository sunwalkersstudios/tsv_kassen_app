import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../repo/settings_repo.dart';
import '../util/app_lock.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _repo = SettingsRepo();
  bool _hasPin = false;

  @override
  void initState() {
    super.initState();
    _loadPinState();
  }

  Future<void> _loadPinState() async {
    final has = await AppLock.hasPin();
    if (mounted) setState(() => _hasPin = has);
  }

  Future<void> _setPin() async {
    final pin = TextEditingController();
    final repeat = TextEditingController();
    String? fehler;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(_hasPin ? 'PIN ändern' : 'PIN festlegen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Die PIN gilt nur für dieses Gerät und entsperrt den '
                'Sperrbildschirm. Für die Anmeldung bleiben E-Mail und Passwort.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              _field(pin, 'Neue PIN (${AppLock.minLength}–${AppLock.maxLength} Ziffern)'),
              const SizedBox(height: 12),
              _field(repeat, 'PIN wiederholen'),
              if (fehler != null) ...[
                const SizedBox(height: 12),
                Text(fehler!, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
            FilledButton(
              onPressed: () async {
                if (pin.text != repeat.text) {
                  setLocal(() => fehler = 'Die beiden Eingaben stimmen nicht überein.');
                  return;
                }
                final problem = await AppLock.setPin(pin.text);
                if (problem != null) {
                  setLocal(() => fehler = problem);
                  return;
                }
                if (ctx.mounted) Navigator.of(ctx).pop(true);
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );

    pin.dispose();
    repeat.dispose();
    if (saved == true) {
      await _loadPinState();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN gespeichert')),
        );
      }
    }
  }

  Future<void> _removePin() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('PIN entfernen?'),
        content: const Text(
          'Ohne PIN und ohne Fingerabdrucksensor lässt sich der Sperrbildschirm '
          'nicht mehr entsperren — dann bleibt nur die erneute Anmeldung.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Entfernen')),
        ],
      ),
    );
    if (ok != true) return;
    await AppLock.clearPin();
    await _loadPinState();
    messenger.showSnackBar(const SnackBar(content: Text('PIN entfernt')));
  }

  Widget _field(TextEditingController c, String label) => TextField(
        controller: c,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: AppLock.maxLength,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 20, letterSpacing: 6),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          counterText: '',
          border: const OutlineInputBorder(),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        children: [
          const _SectionHeader('Betrieb'),
          StreamBuilder<Map<String, dynamic>>(
            stream: _repo.streamOrgSettings(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const ListTile(title: Text('Lade…'));
              }
              if (snap.hasError) {
                return ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: const Text('Einstellungen nicht lesbar'),
                  subtitle: Text('${snap.error}'),
                );
              }
              final merged = (snap.data ?? const {})['mergeKitchenBar'] == true;
              return SwitchListTile(
                title: const Text('Bar und Küche zusammenlegen'),
                subtitle: const Text('Zeigt Bestellungen beider Routen gemeinsam an.'),
                value: merged,
                onChanged: (v) async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await _repo.setMergeKitchenBar(v);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Einstellung gespeichert')),
                    );
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text('Fehler: $e')));
                  }
                },
              );
            },
          ),

          const Divider(),
          const _SectionHeader('Bildschirmsperre auf diesem Gerät'),
          ListTile(
            leading: Icon(_hasPin ? Icons.pin : Icons.pin_outlined),
            title: Text(_hasPin ? 'PIN ist eingerichtet' : 'Keine PIN eingerichtet'),
            subtitle: Text(
              _hasPin
                  ? 'Wird verwendet, wenn kein Fingerabdruck verfügbar ist.'
                  : 'Ohne PIN entsperrt sich der Sperrbildschirm auf Geräten '
                      'ohne Fingerabdrucksensor beim ersten Start selbst.',
            ),
            trailing: FilledButton.tonal(
              onPressed: _setPin,
              child: Text(_hasPin ? 'Ändern' : 'Festlegen'),
            ),
          ),
          if (_hasPin)
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('PIN entfernen'),
              onTap: _removePin,
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.1,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      );
}
