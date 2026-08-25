import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'screens/login_screen.dart';
import 'screens/table_plan_screen.dart';
import 'screens/order_screen.dart';
import 'screens/kitchen_screen.dart';
import 'screens/bar_screen.dart';
import 'screens/cashier_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/admin_devices_screen.dart';
import 'screens/admin_events_screen.dart';
import 'screens/admin_menu_screen.dart';
import 'screens/admin_tables_screen.dart';
import 'screens/admin_print_template_screen.dart';
import 'screens/admin_settings_screen.dart';
import 'state/auth_provider.dart';
import 'state/settings_provider.dart';
import 'models/entities.dart';
import 'screens/unlock_screen.dart';
import 'theme.dart';

class TsvApp extends StatelessWidget {
  const TsvApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();

    String homeForRole(UserRole role) {
      final merged = settings.mergeKitchenBar;
      switch (role) {
        case UserRole.kitchen:
          return '/kitchen';
        case UserRole.bar:
          return merged ? '/kitchen' : '/bar';
        case UserRole.admin:
          return '/admin';
        case UserRole.server:
          return '/tables';
      }
    }

    final router = GoRouter(
      initialLocation: '/login',
      refreshListenable: Listenable.merge([auth, settings]),
      redirect: (context, state) {
        final loggedIn = auth.isAuthenticated;
        final loggingIn = state.matchedLocation == '/login';
        final unlocking = state.matchedLocation == '/unlock';
        final locked = auth.isLocked;
        final path = state.matchedLocation;
        final role = auth.user?.role;
        final merged = settings.mergeKitchenBar;

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
        // Hide/redirect bar when merged
        if (loggedIn && !locked && merged && path.startsWith('/bar')) {
          return '/kitchen';
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
          path: '/admin/devices',
          builder: (context, state) => const AdminDevicesScreen(),
        ),
        GoRoute(
          path: '/admin/settings',
          builder: (context, state) => const AdminSettingsScreen(),
        ),
        GoRoute(
          path: '/admin/print-template',
          builder: (context, state) => const AdminPrintTemplateScreen(),
        ),
      ],
    );

    return MaterialApp.router(
      title: 'TSV KassenApp',
      // Deutsch als einzige Sprache: Datumswaehler, Wochentage und
      // Standardtexte von Material erscheinen sonst auf Englisch.
      locale: const Locale('de', 'DE'),
      supportedLocales: const [Locale('de', 'DE')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Folgt der Systemeinstellung des Tablets: abends dunkel, tagsueber hell.
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
