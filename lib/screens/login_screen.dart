import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/entities.dart';
import '../state/auth_provider.dart';
import '../state/device_context.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passFocus = FocusNode();

  bool _loading = false;
  bool _showPassword = false;
  String? _error;
  List<String> _knownEmails = [];

  @override
  void initState() {
    super.initState();
    _restoreLastLogin();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Future<void> _restoreLastLogin() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final last = sp.getString('lastEmail');
      final org = DeviceContext.deviceOrgId;
      final known = (org != null && org.isNotEmpty)
          ? sp.getStringList('knownEmails:$org') ?? const <String>[]
          : const <String>[];
      if (!mounted) return;
      setState(() {
        if (last != null) _emailCtrl.text = last;
        _knownEmails = known;
      });
    } catch (_) {/* Bequemlichkeit, kein Fehlerfall */}
  }

  /// Ergaenzt eine Domain ohne Punkt um `.local`, damit sich Konten wie
  /// `kellner@tsv` anmelden lassen - Firebase verlangt eine gueltige Domain.
  String _normalizeEmail(String raw) {
    final email = raw.trim();
    final at = email.indexOf('@');
    if (at <= 0) return email;
    final domain = email.substring(at + 1);
    if (domain.contains('.')) return email;
    return '$email.local';
  }

  Future<void> _submit() async {
    if (_loading) return;
    final email = _normalizeEmail(_emailCtrl.text);
    if (email.isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Bitte E-Mail und Passwort eingeben.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = context.read<AuthProvider>();
    final fcm = context.read<FirebaseMessaging>();
    final router = GoRouter.of(context);

    try {
      await auth.login(email: email, password: _passCtrl.text);

      // Push-Token fuer dieses Geraet hinterlegen
      try {
        final token = await fcm.getToken();
        if (token != null) await auth.saveFcmToken(token);
      } catch (_) {/* ohne Push laeuft die App trotzdem */}

      await _rememberEmail(email);

      if (!mounted) return;
      router.go(_homeForRole(auth.user?.role ?? UserRole.server));
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Anmeldung fehlgeschlagen. Bitte erneut versuchen.');
      debugPrint('[LoginScreen] Unerwarteter Anmeldefehler: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _rememberEmail(String email) async {
    try {
      final org = DeviceContext.deviceOrgId;
      if (org == null || org.isEmpty) return;
      final sp = await SharedPreferences.getInstance();
      final key = 'knownEmails:$org';
      final list = sp.getStringList(key) ?? <String>[];
      if (!list.contains(email)) {
        list.add(email);
        await sp.setStringList(key, list);
      }
    } catch (_) {}
  }

  String _homeForRole(UserRole role) {
    switch (role) {
      case UserRole.kitchen:
        return '/kitchen';
      case UserRole.bar:
        return '/bar';
      case UserRole.admin:
        return '/admin';
      case UserRole.server:
        return '/tables';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.point_of_sale, size: 56, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text('TSV KassenApp',
                      textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
                  if (DeviceContext.deviceOrgName != null) ...[
                    const SizedBox(height: 4),
                    Text(DeviceContext.deviceOrgName!,
                        textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 28),

                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    enabled: !_loading,
                    decoration: const InputDecoration(
                      labelText: 'E-Mail',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _passFocus.requestFocus(),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _passCtrl,
                    focusNode: _passFocus,
                    obscureText: !_showPassword,
                    textInputAction: TextInputAction.done,
                    enabled: !_loading,
                    decoration: InputDecoration(
                      labelText: 'Passwort',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                        tooltip: _showPassword ? 'Passwort verbergen' : 'Passwort anzeigen',
                        onPressed: () => setState(() => _showPassword = !_showPassword),
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),

                  if (_knownEmails.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final email in _knownEmails)
                          ActionChip(
                            label: Text(email),
                            onPressed: _loading
                                ? null
                                : () => setState(() => _emailCtrl.text = email),
                          ),
                      ],
                    ),
                  ],

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline,
                              size: 20, color: theme.colorScheme.onErrorContainer),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!,
                                style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Anmelden'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Kein Konto? Die Zugänge legt der Admin unter Admin → Benutzer an.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
