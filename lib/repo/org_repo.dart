import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/organization.dart';

class OrgRepo {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// Check if an organization id already exists.
  Future<bool> orgExists(String orgId) async {
    final doc = await _db.collection('orgs').doc(orgId).get();
    return doc.exists;
  }

  /// Create a new organization and its admin user.
  /// Returns the created Organization and admin uid.
  Future<(Organization, String)> createOrganization({
    required String orgId,
    required String name,
    required String adminEmail,
    required String adminPassword,
  }) async {
    // 1) Create/sign-in admin user (handles case where email was created in a previous failed attempt)
    UserCredential cred;
    bool isNewUser = false;
    try {
      cred = await _auth.createUserWithEmailAndPassword(email: adminEmail, password: adminPassword);
      isNewUser = cred.additionalUserInfo?.isNewUser ?? true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // Try to sign in with the provided password and continue if successful
        try {
          cred = await _auth.signInWithEmailAndPassword(email: adminEmail, password: adminPassword);
          isNewUser = false;
        } on FirebaseAuthException {
          throw Exception('Diese E-Mail ist bereits registriert. Bitte mit diesem Passwort anmelden oder Passwort zurücksetzen.');
        }
      } else {
        rethrow;
      }
    }
    final uid = cred.user!.uid;
    // Send email verification (admin confirms via link)
    try {
      await cred.user!.sendEmailVerification();
    } catch (_) {}

    // 2) Validate orgId availability now that we're signed in (rules allow read when signed in)
    final orgRef = _db.collection('orgs').doc(orgId);
    final existing = await orgRef.get();
    if (existing.exists) {
      // Rollback only if we just created this account in this flow
      if (isNewUser) {
        try { await cred.user!.delete(); } catch (_) {}
      }
      throw Exception('Diese OrgID ist bereits vergeben.');
    }

    // 3) Create org document (rules ensure user has no org yet)
    try {
      await orgRef.set({
        'name': name,
        'adminEmail': adminEmail,
        'emailVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      // If rules deny (e.g., orgId already taken), surface a friendly message
      if (e.code == 'permission-denied') {
        // If the account already belongs to an org, provide a specific hint
        try {
          final userSnap = await _db.collection('users').doc(uid).get();
          final userData = userSnap.data();
          final currentOrg = userData != null ? userData['orgId'] as String? : null;
          if (currentOrg != null && currentOrg.isNotEmpty) {
            throw Exception('Dieses Konto ist bereits mit der Org "$currentOrg" verknüpft. Bitte abmelden und mit einem neuen Admin-Konto registrieren.');
          }
        } catch (_) {
          // ignore secondary diagnostics
        }
        if (isNewUser) {
          try { await cred.user!.delete(); } catch (_) {}
        }
        throw Exception('Die OrgID ist bereits vergeben oder die Berechtigung fehlt.');
      }
      rethrow;
    }

    // 4) Persist user profile
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'email': adminEmail,
      'displayName': name, // or email prefix
      'role': 'admin',
      'orgId': orgId,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final org = Organization(id: orgId, name: name, adminEmail: adminEmail, emailVerified: false);
    return (org, uid);
  }

  /// Mark organization admin email verified (called on app start if currentUser.emailVerified).
  Future<void> markEmailVerifiedIfNeeded(String orgId, String adminEmail) async {
    final ref = _db.collection('orgs').doc(orgId);
    final snap = await ref.get();
    if (snap.exists && (snap.data()?['emailVerified'] != true)) {
      await ref.update({'emailVerified': true});
    }
  }
}
