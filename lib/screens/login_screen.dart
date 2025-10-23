import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/auth_provider.dart';
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
  final emailCtrl = TextEditingController(text: 'kellner@tsv.de');
  final passCtrl = TextEditingController(text: '123456');
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    () async {
      try {
        final sp = await SharedPreferences.getInstance();
        final last = sp.getString('lastEmail');
        if (last != null && mounted) emailCtrl.text = last;
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
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'E-Mail')),
            TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Passwort'), obscureText: true),
            const SizedBox(height: 16),
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
                        await auth.login(email: emailCtrl.text.trim(), password: passCtrl.text);
                        // Save FCM token for this user/device
                        final token = await fcm.getToken();
                        if (token != null) {
                          await auth.saveFcmToken(token);
                        }
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
