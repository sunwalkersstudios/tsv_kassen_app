import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../repo/tickets_repo.dart';
import '../state/tables_provider.dart';
import '../widgets/pending_orders_view.dart';
import '../widgets/user_menu_button.dart';
import '../widgets/connection_indicator.dart';

/// Baransicht: offene Positionen der Route 'bar' als Bon-Karten.
///
/// Teilt die Darstellung mit der Kueche - siehe [PendingOrdersView].
///
/// Die frueher hier eingebaute Weiterleitung bei zusammengelegter Kueche und
/// Bar ist entfallen: sie benutzte `Navigator.pushReplacementNamed`, das mit
/// go_router nicht zusammenpasst, und der Router leitet diesen Fall ohnehin
/// bereits um (siehe app.dart).
class BarScreen extends StatelessWidget {
  const BarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tables = context.watch<TablesProvider>().tables;
    final ticketsRepo = TicketsRepo();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bar'),
        actions: const [ConnectionIndicator(), UserMenuButton()],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: ticketsRepo.streamPendingForRoute('bar'),
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
            route: 'bar',
            onItemFertig: ticketsRepo.markItemReady,
            onTicketFertig: (ticketId) => ticketsRepo.markRouteReady(ticketId, 'bar'),
          );
        },
      ),
    );
  }
}
