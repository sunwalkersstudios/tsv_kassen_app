import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'screens/login_screen.dart';
import 'screens/table_plan_screen.dart';
import 'screens/order_screen.dart';
import 'screens/kitchen_screen.dart';
import 'screens/bar_screen.dart';
import 'screens/cashier_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/admin_events_screen.dart';
import 'screens/admin_menu_screen.dart';
import 'screens/admin_tables_screen.dart';
import 'screens/admin_print_template_screen.dart';
import 'state/auth_provider.dart';
import 'models/entities.dart';
import 'screens/unlock_screen.dart';

class TsvApp extends StatelessWidget {
  const TsvApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    String homeForRole(UserRole role) {
      switch (role) {
        case UserRole.kitchen:
          return '/kitchen';
        case UserRole.bar:
          return '/bar';
        case UserRole.admin:
          return '/admin';
        case UserRole.server:
          return '/tables';
      }
    }

    final router = GoRouter(
      initialLocation: '/login',
      refreshListenable: auth,
      redirect: (context, state) {
        final loggedIn = auth.isAuthenticated;
        final loggingIn = state.matchedLocation == '/login';
        final unlocking = state.matchedLocation == '/unlock';
        final locked = auth.isLocked;
        final path = state.matchedLocation;
        final role = auth.user?.role;

        if (!loggedIn && !loggingIn) return '/login';
        if (loggedIn && locked && !unlocking) return '/unlock';
        // After successful unlock, leave /unlock to the appropriate home
        if (loggedIn && !locked && unlocking) {
          final role = auth.user?.role ?? UserRole.server;
          return homeForRole(role);
        }
        // Guard: cashier is admin-only
        if (loggedIn && !locked && path.startsWith('/cashier')) {
          if (role != UserRole.admin) {
            return homeForRole(role ?? UserRole.server);
          }
        }
        // Guard: admin paths are admin-only
        if (loggedIn && !locked && path.startsWith('/admin')) {
          if (role != UserRole.admin) {
            return homeForRole(role ?? UserRole.server);
          }
        }
        if (loggedIn && !locked && loggingIn) {
          final role = auth.user?.role ?? UserRole.server;
          return homeForRole(role);
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/unlock',
          builder: (context, state) => const UnlockScreen(),
        ),
        GoRoute(
          path: '/tables',
          builder: (context, state) => const TablePlanScreen(),
          routes: [
            GoRoute(
              path: 'order/:tableId',
              builder: (context, state) {
                final tableId = state.pathParameters['tableId']!;
                return OrderScreen(tableId: tableId);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/kitchen',
          builder: (context, state) => const KitchenScreen(),
        ),
        GoRoute(
          path: '/bar',
          builder: (context, state) => const BarScreen(),
        ),
        GoRoute(
          path: '/cashier',
          builder: (context, state) => const CashierScreen(),
        ),
        GoRoute(
          path: '/admin',
          builder: (context, state) => const AdminScreen(),
        ),
        GoRoute(
          path: '/admin/tables',
          builder: (context, state) => const AdminTablesScreen(),
        ),
        GoRoute(
          path: '/admin/events',
          builder: (context, state) => const AdminEventsScreen(),
        ),
        GoRoute(
          path: '/admin/menu',
          builder: (context, state) => const AdminMenuScreen(),
        ),
        GoRoute(
          path: '/admin/print-template',
          builder: (context, state) => const AdminPrintTemplateScreen(),
        ),
      ],
    );

    return MaterialApp.router(
      title: 'TSV KassenApp',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      builder: (context, child) {
        // Add a simple user-switch action in a common AppBar wrapper when appropriate.
        // We'll only show it when authenticated to allow quick role-switch testing by admin.
        return ScaffoldMessenger(
          child: Navigator(
            onGenerateRoute: (settings) => MaterialPageRoute(
              builder: (ctx) {
                return Stack(
                  children: [
                    if (child != null) child,
                    // Floating button for quick user switch
                    if (context.read<AuthProvider>().isAuthenticated && !context.read<AuthProvider>().isLocked)
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: FloatingActionButton.extended(
                          heroTag: 'switchUserFab',
                          icon: const Icon(Icons.switch_account),
                          label: const Text('Nutzer wechseln'),
                          onPressed: () {
                            // Force logout and go to login screen
                            context.read<AuthProvider>().logout();
                            GoRouter.of(context).go('/login');
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
      routerConfig: router,
    );
  }
}
