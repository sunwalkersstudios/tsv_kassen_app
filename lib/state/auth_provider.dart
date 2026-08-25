import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/entities.dart';
import '../repo/settings_repo.dart';
import 'device_context.dart';

/// Anmeldung und Rolle des angemeldeten Nutzers.
///
/// Die Rolle stammt aus den Custom Claims des Auth-Tokens. Frueher lag sie in
/// `users/{uid}.role`, das der Nutzer selbst schreiben durfte - jeder konnte
/// sich damit zum Admin machen. Claims setzt ausschliesslich das Backend
/// (siehe functions/admin_users.js), die App liest sie nur.
///
/// Konten werden hier nicht mehr angelegt. Wer keins hat, bekommt eins vom
/// Admin unter Admin -> Benutzer.
class AuthProvider extends ChangeNotifier {
  FirebaseAuth? _auth;
  FirebaseFirestore? _db;
  StreamSubscription<String>? _tokenSub;

  UserProfile? _user;
  UserProfile? get user => _user;
  bool get isAuthenticated => _user != null;

  bool _locked = false; // Sitzung vorhanden, aber Entsperren steht aus
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
      await _loadProfile(current);
      _locked = true;
      _listenForTokenRefresh();
      notifyListeners();
    }
  }

  void unlock() {
    if (_user != null) {
      _locked = false;
      notifyListeners();
    }
  }

  /// Meldet an. Wirft bei unbekannter Adresse oder falschem Passwort eine
  /// [AuthFailure] mit einer Meldung, die man einer Aushilfe zeigen kann.
  Future<void> login({required String email, required String password}) async {
    try {
      final cred = await _auth!.signInWithEmailAndPassword(email: email, password: password);
      await _loadProfile(cred.user!, tokenIstFrisch: true);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e), code: e.code);
    }

    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString('lastEmail', email);
    } catch (_) {}

    _listenForTokenRefresh();
    notifyListeners();
  }

  /// Meldet ein Personalkonto ohne Passwort an - moeglich nur auf einem
  /// freigeschalteten Geraet.
  ///
  /// Der Token stammt aus der Cloud Function `staffSignIn`, die ihn nur fuer
  /// Nicht-Adminkonten und nur gegen ein gueltiges Geraetegeheimnis ausstellt.
  Future<void> loginWithToken(String customToken) async {
    try {
      final cred = await _auth!.signInWithCustomToken(customToken);
      await _loadProfile(cred.user!, tokenIstFrisch: true);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e), code: e.code);
    }
    _listenForTokenRefresh();
    notifyListeners();
  }

  /// Uebersetzt die Firebase-Fehlercodes in verstaendliches Deutsch.
  /// Bei falschen Zugangsdaten bewusst ohne Hinweis darauf, ob die Adresse
  /// existiert - sonst liesse sich damit herausfinden, wer ein Konto hat.
  String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'E-Mail oder Passwort stimmt nicht.';
      case 'invalid-email':
        return 'Die E-Mail-Adresse sieht nicht richtig aus.';
      case 'user-disabled':
        return 'Dieses Konto ist gesperrt. Bitte beim Admin melden.';
      case 'too-many-requests':
        return 'Zu viele Versuche. Bitte einen Moment warten und erneut probieren.';
      case 'network-request-failed':
        return 'Keine Verbindung. Bitte WLAN prüfen.';
      case 'invalid-custom-token':
      case 'custom-token-mismatch':
        return 'Die Anmeldung dieses Geräts ist nicht mehr gültig. '
            'Bitte einen Admin bitten, das Gerät neu freizuschalten.';
      case 'operation-not-allowed':
        return 'Anmeldung per E-Mail ist im Firebase-Projekt nicht aktiviert.';
      default:
        return 'Anmeldung fehlgeschlagen (${e.code}).';
    }
  }

  void _listenForTokenRefresh() {
    _tokenSub?.cancel();
    _tokenSub = FirebaseMessaging.instance.onTokenRefresh.listen(saveFcmToken);
  }

  Future<void> saveFcmToken(String token) async {
    if (_user == null || token.isEmpty || _db == null) return;
    try {
      await _db!.collection('users').doc(_user!.uid).set({
        'deviceTokens': FieldValue.arrayUnion([token]),
        'lastToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {/* Push ist nicht kritisch */}
  }

  void logout() {
    try {
      _auth?.signOut();
    } catch (_) {}
    _user = null;
    _locked = false;
    _tokenSub?.cancel();
    _tokenSub = null;
    DeviceContext.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _tokenSub?.cancel();
    _tokenSub = null;
    super.dispose();
  }

  // ------------------------------------------------------------------ Profil

  /// Laedt Rolle, Anzeigename und Organisation.
  ///
  /// [tokenIstFrisch] gilt direkt nach einer Anmeldung: der Token kommt dann
  /// gerade vom Server und traegt die Rolle bereits. Ihn trotzdem zu
  /// erneuern waere ein zusaetzlicher Netzweg vor dem ersten Bildschirm.
  Future<void> _loadProfile(User firebaseUser, {bool tokenIstFrisch = false}) async {
    // Die drei Abfragen haengen nicht voneinander ab und laufen deshalb
    // nebeneinander statt hintereinander. Vorher waren es drei Netzwege in
    // Folge, was sich beim Anmelden deutlich bemerkbar machte.
    final rolleF = _roleFromClaims(firebaseUser, erneuern: !tokenIstFrisch);
    final docF = _db!
        .collection('users')
        .doc(firebaseUser.uid)
        .get()
        .then<Map<String, dynamic>?>((d) => d.data())
        .catchError((_) => null);
    final mergedF = SettingsRepo().getMergeKitchenBar().catchError((_) => false);

    final role = await rolleF;
    final data = await docF;
    final merged = await mergedF;

    // Anzeigename und Organisation sind reine Anzeigedaten ohne Rechtewirkung.
    String displayName =
        firebaseUser.displayName ?? firebaseUser.email?.split('@').first ?? firebaseUser.uid;
    String? orgId;
    if (data != null) {
      final n = (data['displayName'] as String?)?.trim();
      if (n != null && n.isNotEmpty) displayName = n;
      orgId = (data['orgId'] as String?)?.trim();
    }

    // Sind Kueche und Bar zusammengelegt, wird die Bar-Rolle fuer die
    // Navigation wie Kueche behandelt. Die echte Rolle bleibt unberuehrt.
    final effective = (role == UserRole.bar && merged) ? UserRole.kitchen : role;

    _user = UserProfile(uid: firebaseUser.uid, displayName: displayName, role: effective);

    // Ohne Warten: der Organisationsname wird erst auf spaeteren Bildschirmen
    // gebraucht und soll den ersten Bildschirm nicht aufhalten.
    if (orgId != null && orgId.isNotEmpty) {
      unawaited(_applyOrgContext(orgId).catchError((_) {}));
    }
  }

  /// Liest die Rolle aus dem Auth-Token.
  ///
  /// [erneuern] erzwingt eine Aktualisierung, damit eine gerade vom Admin
  /// geaenderte Rolle sofort greift und nicht bis zu einer Stunde im alten
  /// Token haengt. Direkt nach einer Anmeldung ist das unnoetig - der Token
  /// ist dann keine Sekunde alt.
  Future<UserRole> _roleFromClaims(User firebaseUser, {bool erneuern = true}) async {
    try {
      final token = await firebaseUser.getIdTokenResult(erneuern);
      final claim = token.claims?['role'];
      if (claim is String && claim.isNotEmpty) return _roleFromString(claim);
    } catch (e) {
      debugPrint('[AuthProvider] Rolle konnte nicht aus dem Token gelesen werden: $e');
    }
    // Ohne Claim gilt die geringste Berechtigung. Ein Konto ohne gesetzte
    // Rolle soll nicht versehentlich mehr duerfen als noetig.
    return UserRole.server;
  }

  Future<void> _applyOrgContext(String orgId) async {
    DeviceContext.deviceOrgId = orgId;
    try {
      final orgSnap = await _db!.collection('orgs').doc(orgId).get();
      final orgName = (orgSnap.data()?['name'] as String?)?.trim();
      if (orgName != null && orgName.isNotEmpty) {
        DeviceContext.deviceOrgName = orgName;
      }
    } catch (_) {}
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString('deviceOrgId', orgId);
      final name = DeviceContext.deviceOrgName;
      if (name != null) await sp.setString('deviceOrgName', name);
    } catch (_) {}
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
}

/// Anmeldefehler mit einer Meldung, die direkt angezeigt werden kann.
class AuthFailure implements Exception {
  final String message;
  final String? code;
  const AuthFailure(this.message, {this.code});

  @override
  String toString() => message;
}
