import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import '../models/entities.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  FirebaseAuth? _auth;
  FirebaseFirestore? _db;
  StreamSubscription<String>? _tokenSub;

  UserProfile? _user;
  UserProfile? get user => _user;
  bool get isAuthenticated => _user != null;
  bool _locked = false; // when true, user exists but app is locked pending biometric
  bool get isLocked => _locked;

  AuthProvider({bool skipInit = false}) {
    if (!skipInit) {
      _auth = FirebaseAuth.instance;
      _db = FirebaseFirestore.instance;
      _init();
    }
  }

  Future<void> _init() async {
    final current = _auth?.currentUser;
    if (current != null) {
      await _loadOrCreateUserDoc(current);
      _locked = true; // require unlock on app start if a session exists
      // Start listening for token refresh
      _tokenSub?.cancel();
      _tokenSub = FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        saveFcmToken(newToken);
      });
      notifyListeners();
    }
  }

  void unlock() {
    if (_user != null) {
      _locked = false;
      notifyListeners();
    }
  }

  Future<void> login({required String email, required String password}) async {
    try {
      // Try sign-in
      final cred = await _auth!.signInWithEmailAndPassword(email: email, password: password);
      await _loadOrCreateUserDoc(cred.user!);
    } on FirebaseAuthException catch (e) {
      // Auto create on first login for prototype convenience
      if (e.code == 'user-not-found') {
        final cred = await _auth!.createUserWithEmailAndPassword(email: email, password: password);
        await _seedUserDoc(cred.user!);
      } else if (e.code == 'operation-not-allowed' ||
          e.code == 'unknown' && (e.message?.toLowerCase().contains('configuration_not_found') ?? false)) {
        throw Exception('E-Mail/Passwort in Firebase aktivieren: Firebase Console → Build → Authentication → „Get started“ → Anmeldemethode → „E-Mail/Passwort“ aktivieren.');
      } else {
        rethrow;
      }
    }
    // Remember last email
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString('lastEmail', email);
    } catch (_) {}
    // Ensure FCM token refresh is saved for this user
    _tokenSub?.cancel();
    _tokenSub = FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      saveFcmToken(newToken);
    });
    notifyListeners();
  }

  Future<void> saveFcmToken(String token) async {
    if (_user == null || token.isEmpty || _db == null) return;
    try {
      await _db!.collection('users').doc(_user!.uid).set({
        'deviceTokens': FieldValue.arrayUnion([token]),
        'lastToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {/* ignore */}
  }

  void logout() {
    try { _auth?.signOut(); } catch (_) {}
    _user = null;
    _locked = false;
    _tokenSub?.cancel();
    _tokenSub = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _tokenSub?.cancel();
    _tokenSub = null;
    super.dispose();
  }

  Future<void> _seedUserDoc(User firebaseUser) async {
    // Heuristic: derive initial role from email prefix to keep flows easy
    final email = firebaseUser.email ?? firebaseUser.uid;
    UserRole role = UserRole.server;
    if (email.startsWith('kueche')) role = UserRole.kitchen;
    if (email.startsWith('bar')) role = UserRole.bar;
    if (email.startsWith('admin')) role = UserRole.admin;
    final doc = _db!.collection('users').doc(firebaseUser.uid);
    await doc.set({
      'uid': firebaseUser.uid,
      'email': firebaseUser.email,
      'displayName': firebaseUser.displayName ?? email.split('@').first,
      'role': role.name,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _user = UserProfile(uid: firebaseUser.uid, displayName: email.split('@').first, role: role);
  }

  Future<void> _loadOrCreateUserDoc(User firebaseUser) async {
    final doc = await _db!.collection('users').doc(firebaseUser.uid).get();
    if (!doc.exists) {
      await _seedUserDoc(firebaseUser);
      return;
    }
    final data = doc.data() ?? {};
    String? roleStr = data['role'] as String?;
    String displayName = (data['displayName'] as String?) ?? firebaseUser.email?.split('@').first ?? firebaseUser.uid;

    // If role missing, derive from email prefix and write back
    if (roleStr == null || roleStr.isEmpty) {
      final email = firebaseUser.email ?? firebaseUser.uid;
      final derived = _roleFromString(_deriveRoleFromEmail(email).name);
      roleStr = derived.name;
      await _db!.collection('users').doc(firebaseUser.uid).set({
        'role': roleStr,
        'displayName': displayName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    final role = _roleFromString(roleStr);
    _user = UserProfile(uid: firebaseUser.uid, displayName: displayName, role: role);
  }

  UserRole _roleFromString(String s) {
    switch (s) {
      case 'kitchen':
        return UserRole.kitchen;
      case 'bar':
        return UserRole.bar;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.server;
    }
  }

  UserRole _deriveRoleFromEmail(String email) {
    if (email.startsWith('kueche')) return UserRole.kitchen;
    if (email.startsWith('bar')) return UserRole.bar;
    if (email.startsWith('admin')) return UserRole.admin;
    return UserRole.server;
  }

}
