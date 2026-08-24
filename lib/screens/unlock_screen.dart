import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../models/entities.dart';
import '../state/auth_provider.dart';
import '../util/app_lock.dart';

/// Sperrbildschirm nach dem Start oder beim Zurueckkehren in die App.
///
/// Bisher entsperrte sich der Bildschirm auf Geraeten ohne Biometrie sofort
/// selbst - die Sperre war dort wirkungslos. Jetzt gilt: Fingerabdruck wenn
/// vorhanden, sonst PIN. Ist noch keine PIN eingerichtet, wird beim ersten Mal
/// eine angelegt.
class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

enum _Mode { pruefe, biometrie, pinEingabe, pinAnlegen }

class _UnlockScreenState extends State<UnlockScreen> {
  final _pinCtrl = TextEditingController();
  final _pinRepeatCtrl = TextEditingController();

  _Mode _mode = _Mode.pruefe;
  bool _busy = false;
  String? _error;
  int _fehlversuche = 0;

  @override
  void initState() {
    super.initState();
    _determineMode();
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    _pinRepeatCtrl.dispose();
    super.dispose();
  }

  Future<void> _determineMode() async {
    bool biometrie = false;
    try {
      final la = LocalAuthentication();
      biometrie = await la.canCheckBiometrics && await la.isDeviceSupported();
    } catch (_) {
      biometrie = false;
    }

    if (!mounted) return;
    if (biometrie) {
      setState(() => _mode = _Mode.biometrie);
      _tryBiometric();
      return;
    }

    final hasPin = await AppLock.hasPin();
    if (!mounted) return;
    setState(() => _mode = hasPin ? _Mode.pinEingabe : _Mode.pinAnlegen);
  }

  void _unlock() {
    context.read<AuthProvider>().unlock();
  }

  Future<void> _tryBiometric() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = LocalAuthentication();
      final ok = await auth.authenticate(
        localizedReason: 'Zum Entsperren bestätigen',
        biometricOnly: true,
        // hiess in local_auth 2.x noch stickyAuth
        persistAcrossBackgrounding: true,
      );
      if (!mounted) return;
      if (ok) {
        _unlock();
      } else {
        setState(() => _error = 'Entsperren abgebrochen.');
      }
    } catch (e) {
      if (!mounted) return;
      // Biometrie kann zur Laufzeit wegfallen, etwa wenn der Fingerabdruck
      // entfernt wurde. Dann auf die PIN ausweichen statt zu blockieren.
      final hasPin = await AppLock.hasPin();
      if (!mounted) return;
      setState(() {
        _mode = hasPin ? _Mode.pinEingabe : _Mode.pinAnlegen;
        _error = 'Fingerabdruck nicht verfügbar.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitPin() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await AppLock.verify(_pinCtrl.text);
    if (!mounted) return;
    if (ok) {
      _unlock();
      return;
    }
    setState(() {
      _busy = false;
      _fehlversuche++;
      _pinCtrl.clear();
      _error = _fehlversuche >= 3
          ? 'PIN falsch. Über „Anderer Nutzer" kannst du dich neu anmelden.'
          : 'PIN falsch.';
    });
  }

  Future<void> _createPin() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    if (_pinCtrl.text != _pinRepeatCtrl.text) {
      setState(() {
        _busy = false;
        _error = 'Die beiden Eingaben stimmen nicht überein.';
      });
      return;
    }
    final problem = await AppLock.setPin(_pinCtrl.text);
    if (!mounted) return;
    if (problem != null) {
      setState(() {
        _busy = false;
        _error = problem;
      });
      return;
    }
    _unlock();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthProvider>().user;
    final role = user?.role ?? UserRole.server;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    _mode == _Mode.biometrie ? Icons.fingerprint : Icons.lock_outline,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text('Gesperrt',
                      textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text('${user?.displayName ?? ''} · ${_roleLabel(role)}',
                      textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 28),
                  ..._content(theme),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.error)),
                  ],
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: _busy ? null : () => context.read<AuthProvider>().logout(),
                    child: const Text('Anderer Nutzer'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _content(ThemeData theme) {
    switch (_mode) {
      case _Mode.pruefe:
        return const [Center(child: CircularProgressIndicator())];

      case _Mode.biometrie:
        return [
          FilledButton.icon(
            onPressed: _busy ? null : _tryBiometric,
            icon: const Icon(Icons.lock_open),
            label: Text(_busy ? 'Prüfe…' : 'Mit Fingerabdruck entsperren'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
        ];

      case _Mode.pinEingabe:
        return [
          _pinField(_pinCtrl, 'PIN', autofocus: true, onSubmit: _submitPin),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _submitPin,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: const Text('Entsperren'),
          ),
        ];

      case _Mode.pinAnlegen:
        return [
          Text(
            'Dieses Gerät hat keinen Fingerabdrucksensor. '
            'Bitte eine PIN für die Bildschirmsperre festlegen.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          _pinField(_pinCtrl, 'Neue PIN (${AppLock.minLength}–${AppLock.maxLength} Ziffern)',
              autofocus: true),
          const SizedBox(height: 12),
          _pinField(_pinRepeatCtrl, 'PIN wiederholen', onSubmit: _createPin),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _createPin,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: const Text('PIN speichern'),
          ),
        ];
    }
  }

  Widget _pinField(
    TextEditingController c,
    String label, {
    bool autofocus = false,
    VoidCallback? onSubmit,
  }) =>
      TextField(
        controller: c,
        autofocus: autofocus,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: AppLock.maxLength,
        enabled: !_busy,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, letterSpacing: 8),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          counterText: '',
          border: const OutlineInputBorder(),
        ),
        onSubmitted: onSubmit == null ? null : (_) => onSubmit(),
      );

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.kitchen:
        return 'Küche';
      case UserRole.bar:
        return 'Bar';
      case UserRole.server:
        return 'Kellner';
    }
  }
}
