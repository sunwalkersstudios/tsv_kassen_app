import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/events_provider.dart';

class AdminEventsScreen extends StatelessWidget {
  const AdminEventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final events = context.watch<EventsProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Veranstaltungen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context),
          )
        ],
      ),
      body: ListView.builder(
        itemCount: events.events.length,
        itemBuilder: (context, index) {
          final e = events.events[index];
          return ListTile(
            title: Text(e.name),
            subtitle: Text(e.active ? 'Aktiv' : 'Inaktiv'),
            leading: Switch(
              value: e.active,
              onChanged: (val) async {
                await events.setActive(e.id, val);
              },
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                await events.deleteEvent(e.id);
              },
            ),
            onTap: () async {
              await _showEditDialog(context, e.name, (newName) async {
                final updated = e..name = newName;
                await events.updateEvent(updated);
              });
            },
          );
        },
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Veranstaltung hinzufügen'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Name')), 
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Speichern')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await context.read<EventsProvider>().addEvent(name: ctrl.text.trim());
    }
  }

  Future<void> _showEditDialog(BuildContext context, String current, Future<void> Function(String) onSave) async {
    final ctrl = TextEditingController(text: current);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Veranstaltung bearbeiten'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Name')), 
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Speichern')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await onSave(ctrl.text.trim());
    }
  }
}
