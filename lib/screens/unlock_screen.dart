import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../state/auth_provider.dart';
import '../models/entities.dart';

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  bool _checking = false;
  String? _error;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    // Check biometric availability; if not available, auto-unlock
    () async {
      try {
        final la = LocalAuthentication();
        final can = await la.canCheckBiometrics;
        final supported = await la.isDeviceSupported();
        if (!can || !supported) {
          if (!mounted) return;
          // No biometrics -> don't offer, just unlock directly
          context.read<AuthProvider>().unlock();
          return;
        }
        if (mounted) setState(() => _biometricAvailable = true);
      } catch (_) {
        if (!mounted) return;
        context.read<AuthProvider>().unlock();
      }
    }();
  }

  Future<void> _tryUnlock() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final auth = LocalAuthentication();
      final canCheck = await auth.canCheckBiometrics;
      final supported = await auth.isDeviceSupported();
      if (!canCheck || !supported) {
        setState(() => _error = 'Biometrie nicht verfügbar');
        return;
      }
      final did = await auth.authenticate(
        localizedReason: 'Per Fingerabdruck entsperren',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      if (did && mounted) {
        context.read<AuthProvider>().unlock();
      } else {
        setState(() => _error = 'Entsperren abgebrochen');
      }
    } catch (e) {
      setState(() => _error = 'Fehler: $e');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final role = user?.role ?? UserRole.server;
    return Scaffold(
      appBar: AppBar(title: const Text('Entsperren')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_biometricAvailable)
                Icon(Icons.fingerprint, size: 72, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text('Angemeldet als: ${user?.displayName ?? ''} (${role.name})'),
              const SizedBox(height: 12),
              if (_error != null && _biometricAvailable) Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 24),
              if (_biometricAvailable)
                ElevatedButton.icon(
                  onPressed: _checking ? null : _tryUnlock,
                  icon: const Icon(Icons.lock_open),
                  label: Text(_checking ? 'Prüfe…' : 'Mit Fingerabdruck entsperren'),
                ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _checking ? null : () => context.read<AuthProvider>().logout(),
                child: const Text('Anderer Nutzer'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
