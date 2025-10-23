import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../state/tables_provider.dart';
import '../state/auth_provider.dart';
import '../repo/tickets_repo.dart';

class TablePlanScreen extends StatelessWidget {
  const TablePlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tables = context.watch<TablesProvider>();
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Tischplan')),
      body: auth.user == null
          ? const Center(child: Text('Bitte anmelden'))
          : StreamBuilder<Map<String, Map<String, bool>>>(
              stream: TicketsRepo().streamRouteFlagsAll(),
              builder: (context, snap) {
                final flags = snap.data ?? const <String, Map<String, bool>>{};
                if (tables.tables.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Keine Tische gefunden. Bitte im Admin-Bereich anlegen (Admin → Tische).',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                      ),
                    ),
                  );
                }
                final visibleTables = tables.tables.where((t) => t.active).toList();
                if (visibleTables.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Keine aktiven Tische. Bitte im Admin-Bereich aktivieren (Admin → Tische).',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                      ),
                    ),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 260,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.05,
                  ),
                  itemCount: visibleTables.length,
                  itemBuilder: (context, index) {
                    final t = visibleTables[index];
                    final f = flags[t.id] ?? const {'kitchen': false, 'bar': false, 'billable': false};
                    final isBillable = f['billable'] == true;
                    final kitchenReady = f['kitchen'] == true;
                    final barReady = f['bar'] == true;
                    return Material(
                      elevation: 3,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => context.go('/tables/order/${t.id}'),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Theme.of(context).colorScheme.primary.withOpacity(0.12),
                                Theme.of(context).colorScheme.primaryContainer.withOpacity(0.25),
                              ],
                            ),
                          ),
                          child: Stack(
                            children: [
                              // Content center
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.table_bar, size: 48, color: Theme.of(context).colorScheme.primary.withOpacity(0.8)),
                                    const SizedBox(height: 10),
                                    Text(
                                      t.name,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.9),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Badges top-right
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (kitchenReady)
                                      Chip(
                                        label: const Text('Speisen'),
                                        backgroundColor: Colors.orange.shade200,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                      ),
                                    if (barReady)
                                      Chip(
                                        label: const Text('Getränke'),
                                        backgroundColor: Colors.blue.shade200,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                      ),
                                    if (isBillable)
                                      Chip(
                                        label: const Text('Bereit'),
                                        backgroundColor: Colors.green.shade200,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
