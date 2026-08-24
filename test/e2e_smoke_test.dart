import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tsv/firebase_options.dart';
import 'package:tsv/repo/sales_repo.dart' as app_repos;
import 'package:tsv/repo/tickets_repo.dart' as app_repos2;
import 'package:tsv/state/device_context.dart' as dc;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Dieser Test spricht echtes Firebase an und braucht ein per
  // `flutterfire configure` erzeugtes firebase_options.dart sowie laufende
  // Emulatoren. Als Unit-Test laeuft er deshalb nicht mit.
  group('E2E smoke (org scoped)', skip: 'Benoetigt Firebase-Konfiguration und Emulatoren', () {
    late FirebaseFirestore db;
    late FirebaseAuth auth;
    late String orgId;
    late String adminEmail;
    const String tableName = 'T1';

    setUpAll(() async {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      db = FirebaseFirestore.instance;
      auth = FirebaseAuth.instance;
      final ts = DateTime.now().millisecondsSinceEpoch;
      orgId = 'orgsmoke_$ts';
      adminEmail = 'admin+$ts@example.com';

      final pw = 'Test${Random().nextInt(999999)}!aA';
      final cred = await auth.createUserWithEmailAndPassword(email: adminEmail, password: pw);
      final uid = cred.user!.uid;

      // Self-profile with admin role and orgId
      await db.collection('users').doc(uid).set({
        'uid': uid,
        'email': adminEmail,
        'displayName': 'Smoke Admin',
        'role': 'admin',
        'orgId': orgId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Make repos/org-scoped lookups point to this org without SharedPreferences
      dc.DeviceContext.deviceOrgId = orgId;
      dc.DeviceContext.deviceOrgName = 'Smoke Test';
    });

    test('menu/tables/events create and ticket flow', () async {
      // Create a menu item (base)
      final menuRef = await db.collection('menu').add({
        'name': 'Test Cola',
        'price': 2.5,
        'category': 'Getränke',
        'route': 'bar',
        'eventId': 'base',
        'orgId': orgId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create a table
      final tableRef = await db.collection('tables').add({
        'name': tableName,
        'row': 0,
        'col': 0,
        'active': true,
        'orgId': orgId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      expect(menuRef.id, isNotEmpty);
      expect(tableRef.id, isNotEmpty);

      // Create a new ticket as admin
      final uid = auth.currentUser!.uid;
      final ticketRef = await db.collection('tickets').add({
        'tableId': tableRef.id,
        'tableName': tableName,
        'serverId': uid,
        'status': 'open',
        'orgId': orgId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add an item to the ticket
      await ticketRef.collection('items').add({
        'menuItemId': menuRef.id,
        'qty': 2,
        'route': 'bar',
        'notes': 'ohne Eis',
        'name': 'Test Cola',
        'price': 2.5,
        'category': 'Getränke',
        'status': 'open',
        'tableId': tableRef.id,
        'orgId': orgId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Verify items (no collectionGroup to avoid index prompts)
      final itemsSnap = await ticketRef.collection('items').get();
      expect(itemsSnap.docs, isNotEmpty);

      // Mark ticket paid via repo (writes a sale with orgId)
      final tRepo = app_repos2.TicketsRepo();
      final saleId = await tRepo.markTicketPaid(ticketRef.id, paymentMethod: 'cash');
      expect(saleId, isNotEmpty);

      // Verify sales via SalesRepo stream
      final sRepo = app_repos.SalesRepo();
      final now = DateTime.now();
      final day = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final sales = await sRepo.fetchSalesForDay(day);
      expect(sales.where((m) => m['orgId'] == orgId).isNotEmpty, true);
    });
  });
}
