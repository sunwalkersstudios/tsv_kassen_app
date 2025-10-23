import 'package:flutter/material.dart';
import '../repo/tables_repo.dart';

class AdminTablesScreen extends StatelessWidget {
  const AdminTablesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = TablesRepo();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tische verwalten'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEdit(context, repo),
          )
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: repo.streamAll(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final tables = snap.data!;
          return ListView.builder(
            itemCount: tables.length,
            itemBuilder: (context, index) {
              final t = tables[index];
              return ListTile(
                title: Text(t['name'] as String),
                subtitle: Text('Pos: ${t['row']}:${t['col']} • ${t['active'] == true ? 'aktiv' : 'inaktiv'}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showAddEdit(context, repo, id: t['id'] as String, current: t),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => repo.delete(t['id'] as String),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showAddEdit(BuildContext context, TablesRepo repo, {String? id, Map<String, dynamic>? current}) async {
    final name = TextEditingController(text: current?['name'] as String? ?? '');
    final row = TextEditingController(text: (current?['row']?.toString()) ?? '0');
    final col = TextEditingController(text: (current?['col']?.toString()) ?? '0');
    bool active = (current?['active'] as bool?) ?? true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(id == null ? 'Tisch hinzufügen' : 'Tisch bearbeiten'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: row, decoration: const InputDecoration(labelText: 'Reihe'), keyboardType: TextInputType.number),
            TextField(controller: col, decoration: const InputDecoration(labelText: 'Spalte'), keyboardType: TextInputType.number),
            SwitchListTile(
              value: active,
              onChanged: (v) => active = v,
              title: const Text('Aktiv'),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Speichern')),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      final r = int.tryParse(row.text) ?? 0;
      final c = int.tryParse(col.text) ?? 0;
      if (id == null) {
        await repo.add(name: name.text.trim(), row: r, col: c, active: active);
      } else {
        await repo.update(id, name: name.text.trim(), row: r, col: c, active: active);
      }
    }
  }
}
