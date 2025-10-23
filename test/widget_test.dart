// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:tsv/app.dart';
import 'package:provider/provider.dart';
import 'package:tsv/state/auth_provider.dart';
import 'package:tsv/models/entities.dart';
import 'package:tsv/state/menu_provider.dart';
import 'package:tsv/state/tables_provider.dart';
import 'package:tsv/state/tickets_provider.dart';

void main() {
  // Lightweight mock to avoid Firebase in widget tests

  testWidgets('App builds (smoke test without Firebase)', (WidgetTester tester) async {
    final tables = TablesProvider(subscribe: false);
    tables.seedTestTables([
      TableEntity(id: 't1', name: 'Tisch 1', row: 0, col: 0, active: true),
      TableEntity(id: 't2', name: 'Tisch 2', row: 0, col: 1, active: true),
    ]);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider(skipInit: true)),
          ChangeNotifierProvider(create: (_) => tables),
          ChangeNotifierProvider(create: (_) => MenuProvider()..seedDefaults()),
          ChangeNotifierProvider(create: (_) => TicketsProvider()),
        ],
        child: const TsvApp(),
      ),
    );
    expect(find.byType(TsvApp), findsOneWidget);
  });
}
