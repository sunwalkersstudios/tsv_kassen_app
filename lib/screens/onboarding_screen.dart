import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../repo/org_repo.dart';
// DeviceContext is not needed in single-tenant mode
// auth_provider import no longer needed after inline sign-in in repo

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _form = GlobalKey<FormState>();
  final _orgIdCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pw2Ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _orgIdCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _pw2Ctrl.dispose();
    super.dispose();
  }

  String? _validateOrgId(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Bitte OrgID angeben';
    if (!RegExp(r'^[a-z0-9-]{3,32}$').hasMatch(s)) {
      return '3-32 Zeichen, nur a-z, 0-9, Bindestrich';
    }
    if (s.startsWith('-') || s.endsWith('-')) return 'Kein Bindestrich am Anfang/Ende';
    return null;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_pwCtrl.text != _pw2Ctrl.text) {
      setState(() => _error = 'Passwörter stimmen nicht überein');
      return;
    }
    final orgId = _orgIdCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pw = _pwCtrl.text;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = OrgRepo();
      // Create organization (this will also create and sign in the admin user)
  await repo.createOrganization(orgId: orgId, name: name, adminEmail: email, adminPassword: pw
  );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bestätigungslink gesendet. Bitte E-Mail prüfen.')),
      );
      context.go('/admin');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restaurant anlegen')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('OrgID (Login-Kennung)', style: TextStyle(fontWeight: FontWeight.bold)),
              TextFormField(
                controller: _orgIdCtrl,
                decoration: const InputDecoration(hintText: 'z. B. trattoria-roma'),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: _validateOrgId,
              ),
              const SizedBox(height: 12),
              const Text('Restaurantname', style: TextStyle(fontWeight: FontWeight.bold)),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(hintText: 'z. B. Trattoria Roma'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Bitte Namen angeben' : null,
              ),
              const SizedBox(height: 12),
              const Text('Geschäfts-E-Mail (Admin)', style: TextStyle(fontWeight: FontWeight.bold)),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(hintText: 'name@restaurant.de'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || !v.contains('@')) ? 'Gültige E-Mail angeben' : null,
              ),
              const SizedBox(height: 12),
              const Text('Passwort (Admin)', style: TextStyle(fontWeight: FontWeight.bold)),
              TextFormField(
                controller: _pwCtrl,
                decoration: const InputDecoration(hintText: '••••••••'),
                obscureText: true,
                validator: (v) => (v == null || v.length < 6) ? 'Mindestens 6 Zeichen' : null,
              ),
              const SizedBox(height: 12),
              const Text('Passwort wiederholen', style: TextStyle(fontWeight: FontWeight.bold)),
              TextFormField(
                controller: _pw2Ctrl,
                decoration: const InputDecoration(hintText: '••••••••'),
                obscureText: true,
                validator: (v) => (v == null || v.length < 6) ? 'Mindestens 6 Zeichen' : null,
              ),
              const SizedBox(height: 16),
              if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.rocket_launch),
                  onPressed: _loading ? null : _submit,
                  label: Text(_loading ? 'Lege an…' : 'Restaurant anlegen'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loading ? null : () => context.go('/login'),
                child: const Text('Zurück zum Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

