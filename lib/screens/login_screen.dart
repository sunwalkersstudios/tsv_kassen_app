import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/auth_provider.dart';
import '../state/device_context.dart';
import '../models/entities.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = false;
  String? error;
  List<String> knownEmails = [];

  @override
  void initState() {
    super.initState();
    () async {
      try {
        final sp = await SharedPreferences.getInstance();
        final last = sp.getString('lastEmail');
        if (last != null && mounted) {
          emailCtrl.text = last;
        } else {
          final org = DeviceContext.deviceOrgId;
          if (org != null && org.isNotEmpty && mounted) {
            // No default suggestion to avoid implying non-existing accounts
            // Keep field empty but load known emails for quick-pick chips
          }
        }
        // Load per-device known logins for this org (only those that logged in on this device)
        final org = DeviceContext.deviceOrgId;
        if (org != null && org.isNotEmpty) {
          final list = sp.getStringList('knownEmails:$org') ?? const [];
          if (mounted) setState(() { knownEmails = list; });
        }
      } catch (_) {}
    }();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (DeviceContext.deviceOrgName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Anmelden für: ${DeviceContext.deviceOrgName} (${DeviceContext.deviceOrgId})'),
              ),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'E-Mail')), 
            TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Passwort'), obscureText: true),
            const SizedBox(height: 8),
            if (DeviceContext.deviceOrgId != null && knownEmails.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final email in knownEmails)
                    ActionChip(
                      label: Text(email),
                      onPressed: () { setState(() { emailCtrl.text = email; }); },
                    ),
                ],
              ),
            const SizedBox(height: 16),
            // Onboarding removed/hidden: no entry point from login screen.
            if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (mounted) setState(() => loading = true);
                      try {
                        final auth = context.read<AuthProvider>();
                        final fcm = context.read<FirebaseMessaging>();
                        // Normalize email: if domain has no dot, append .local
                        var email = emailCtrl.text.trim();
                        final at = email.indexOf('@');
                        if (at > 0) {
                          final domain = email.substring(at + 1);
                          if (!domain.contains('.')) {
                            email = '${email.substring(0, at + 1)}$domain.local';
                          }
                        }
                        await auth.login(email: email, password: passCtrl.text);
                        // Save FCM token for this user/device
                        final token = await fcm.getToken();
                        if (token != null) {
                          await auth.saveFcmToken(token);
                        }
                        // Remember this email under knownEmails for this org on this device
                        try {
                          final sp = await SharedPreferences.getInstance();
                          final org = DeviceContext.deviceOrgId;
                          if (org != null && org.isNotEmpty) {
                            final key = 'knownEmails:$org';
                            final list = sp.getStringList(key) ?? <String>[];
                            if (!list.contains(email)) {
                              list.add(email);
                              await sp.setStringList(key, list);
                              if (mounted) setState(() { knownEmails = list; });
                            }
                          }
                        } catch (_) {}
                        final role = auth.user!.role;
                        switch (role) {
                          case UserRole.server:
                            if (!context.mounted) return; context.go('/tables');
                            break;
                          case UserRole.kitchen:
                            if (!context.mounted) return; context.go('/kitchen');
                            break;
                          case UserRole.bar:
                            if (!context.mounted) return; context.go('/bar');
                            break;
                          case UserRole.admin:
                            if (!context.mounted) return; context.go('/admin');
                            break;
                        }
                      } catch (e) {
                        if (!mounted) return;
                        setState(() => error = e.toString());
                      } finally {
                        if (mounted) setState(() => loading = false);
                      }
                    },
              child: const Text('Anmelden'),
            ),
          ],
        ),
      ),
    );
  }
}
