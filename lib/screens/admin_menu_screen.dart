import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/events_provider.dart';
import '../repo/menu_repo.dart';
import '../models/entities.dart';

class AdminMenuScreen extends StatefulWidget {
  const AdminMenuScreen({super.key});
  @override
  State<AdminMenuScreen> createState() => _AdminMenuScreenState();
}

class _AdminMenuScreenState extends State<AdminMenuScreen> {
  String? _filterEventId; // null => Basis

  @override
  Widget build(BuildContext context) {
    final eventsProv = context.watch<EventsProvider>();
    final repo = MenuRepo();
    final events = eventsProv.events; // assume provider exposes list of events
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menü verwalten'),
        actions: [
          IconButton(
            tooltip: 'Artikel hinzufügen',
            icon: const Icon(Icons.add),
            onPressed: () async {
              await _showAdd(context, repo, events);
            },
          ),
          IconButton(
            tooltip: 'Demo füllen (Basis-Artikel)',
            icon: const Icon(Icons.download_for_offline),
            onPressed: () async {
              try {
                await repo.addItem(name: 'Cola', price: 2.8, category: 'Getränke', route: 'bar', eventId: null);
                await repo.addItem(name: 'Schnitzel', price: 12.5, category: 'Speisen', route: 'kitchen', eventId: null);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demo-Artikel hinzugefügt')));
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
              }
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('Filter:'),
                const SizedBox(width: 12),
                DropdownButton<String?>(
                  value: _filterEventId,
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Basis')),
                    ...events.map((e) => DropdownMenuItem<String?>(
                          value: e.id,
                          child: Text(e.name),
                        )),
                  ],
                  onChanged: (v) => setState(() => _filterEventId = v),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _MenuList(stream: repo.streamAll(eventId: _filterEventId)),
      floatingActionButton: FloatingActionButton(
        onPressed: () async => _showAdd(context, repo, events),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAdd(BuildContext context, MenuRepo repo, List<dynamic> events) async {
    final name = TextEditingController();
    final price = TextEditingController();
    String category = 'Speisen';
    bool eventSpecific = _filterEventId != null; // preselect based on filter
    String? selectedEventId = _filterEventId; // prefill from filter
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Artikel hinzufügen'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  textInputAction: TextInputAction.next,
                ),
                TextField(
                  controller: price,
                  decoration: const InputDecoration(labelText: 'Preis (z.B. 5,40 oder 5.40)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                DropdownButtonFormField(
                  initialValue: category,
                  items: const [
                    DropdownMenuItem(value: 'Speisen', child: Text('Speisen (Küche)')),
                    DropdownMenuItem(value: 'Getränke', child: Text('Getränke (Bar)')),
                  ],
                  onChanged: (v) => setState(() => category = v ?? 'Speisen'),
                  decoration: const InputDecoration(labelText: 'Kategorie'),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: eventSpecific,
                  onChanged: (v) => setState(() {
                    eventSpecific = v ?? false;
                    if (!eventSpecific) selectedEventId = null;
                  }),
                  title: const Text('Event-spezifisch'),
                  subtitle: const Text('Nur sichtbar, wenn das jeweilige Event aktiv ist'),
                ),
                if (eventSpecific)
                  DropdownButtonFormField<String>(
                    initialValue: selectedEventId,
                    items: events
                        .map((e) => DropdownMenuItem<String>(
                              value: e.id,
                              child: Text(e.name),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => selectedEventId = v),
                    decoration: const InputDecoration(labelText: 'Event auswählen'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Speichern')),
          ],
        ),
      ),
    );
    if (ok == true) {
      final nm = name.text.trim();
      final prStr = price.text.replaceAll(RegExp(r'[^0-9,\\.-]'), '').replaceAll(',', '.').trim();
      final pr = double.tryParse(prStr);
      if (nm.isEmpty || pr == null || pr <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bitte Namen und gültigen Preis (> 0) angeben')));
        }
        return;
      }
      if (eventSpecific && (selectedEventId == null || selectedEventId!.isEmpty)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bitte ein Event auswählen oder Event-spezifisch deaktivieren')));
        }
        return;
      }
      final route = category == 'Getränke' ? 'bar' : 'kitchen';
      try {
        await repo.addItem(
          name: nm,
          price: pr,
          category: category,
          route: route,
          eventId: eventSpecific ? selectedEventId : null,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Artikel gespeichert')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
        }
      }
    }
  }
}

class _MenuList extends StatelessWidget {
  final Stream<List<MenuItemEntity>> stream;
  const _MenuList({required this.stream});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MenuItemEntity>>(
      stream: stream,
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final items = snap.data!;
        if (items.isEmpty) {
          return const Center(child: Text('Keine Artikel vorhanden'));
        }
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final m = items[index];
            return ListTile(
              title: Text(m.name),
              subtitle: Text('${m.category} • ${m.route} • ${m.price.toStringAsFixed(2)} €'),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () async {
                  try {
                    await MenuRepo().deleteItem(m.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Artikel gelöscht')));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
                    }
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}
