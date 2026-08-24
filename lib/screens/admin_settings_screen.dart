import 'package:flutter/material.dart';
import '../repo/settings_repo.dart';

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = SettingsRepo();
    return Scaffold(
      appBar: AppBar(title: const Text('Restaurant-Einstellungen')),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: repo.streamOrgSettings(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Fehler: ${snap.error}'));
          }
          final data = snap.data ?? const {};
          final merged = data['mergeKitchenBar'] == true;
          return ListView(
            children: [
              SwitchListTile(
                title: const Text('Bar und Küche zusammenlegen'),
                subtitle: const Text('Zeigt Bestellungen beider Routen gemeinsam an.'),
                value: merged,
                onChanged: (v) async {
                  try {
                    await repo.setMergeKitchenBar(v);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Einstellung gespeichert')));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
