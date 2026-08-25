import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../repo/settings_repo.dart';
import '../repo/tickets_repo.dart';
import '../state/tables_provider.dart';
import '../widgets/pending_orders_view.dart';
import '../widgets/user_menu_button.dart';
import '../widgets/connection_indicator.dart';

/// Kuechenansicht: offene Positionen der Route 'kitchen' als Bon-Karten.
///
/// Die Darstellung liegt in [PendingOrdersView] und wird mit der Bar geteilt -
/// beide Bildschirme waren zuvor fast zeichengleiche Kopien.
class KitchenScreen extends StatelessWidget {
  const KitchenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tables = context.watch<TablesProvider>().tables;
    final ticketsRepo = TicketsRepo();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Küche'),
        actions: const [ConnectionIndicator(), UserMenuButton()],
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: SettingsRepo().streamOrgSettings(),
        builder: (context, settingsSnap) {
          final merged = (settingsSnap.data ?? const {})['mergeKitchenBar'] == true;

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: merged
                ? ticketsRepo.streamPendingMerged()
                : ticketsRepo.streamPendingForRoute('kitchen'),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Bestellungen konnten nicht geladen werden.\n${snap.error}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                );
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return PendingOrdersView(
                positionen: snap.data!,
                tische: tables,
                route: 'kitchen',
                merged: merged,
                onItemFertig: ticketsRepo.markItemReady,
                onTicketFertig: (ticketId) => ticketsRepo.markRouteReady(ticketId, 'kitchen'),
              );
            },
          );
        },
      ),
    );
  }
}
