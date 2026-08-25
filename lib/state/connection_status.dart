import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Meldet, ob die App gerade Verbindung zu Firestore hat.
///
/// Firestore arbeitet offline weiter: Lesezugriffe kommen aus dem
/// Zwischenspeicher, Schreibzugriffe warten und werden nachgereicht, sobald es
/// wieder geht. Das ist im Vereinsheim mit wackeligem WLAN genau richtig - hat
/// aber eine Tuecke: Ohne Hinweis glaubt der Kellner, die Bestellung liege in
/// der Kueche, waehrend sie noch auf dem Geraet wartet.
///
/// Erkannt wird der Zustand ueber die Herkunft der Daten. Kommt ein
/// Schnappschuss aus dem Zwischenspeicher statt vom Server, ist die Verbindung
/// vermutlich weg. Kurze Aussetzer sind normal, deshalb gilt die Verbindung
/// erst nach [_wartezeit] als unterbrochen.
///
/// Der Fuehler haengt am Anmeldezustand und nicht am App-Start. Der erste
/// Anlauf tat das und lief prompt in die Falle: beim Start ist niemand
/// angemeldet, die Regeln verlangen aber eine Anmeldung, der Datenstrom brach
/// mit "permission denied" ab - und die Anzeige stand danach dauerhaft auf
/// "Offline", obwohl alles lief.
class ConnectionStatus extends ChangeNotifier {
  static const _wartezeit = Duration(seconds: 4);
  static const _neuerVersuch = Duration(seconds: 10);

  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  Timer? _timer;
  Timer? _retry;

  bool _angemeldet = false;
  bool _offline = false;
  bool _ausstehendeSchreibvorgaenge = false;

  /// True, wenn seit mehreren Sekunden nur noch Daten aus dem Zwischenspeicher
  /// kommen. Solange niemand angemeldet ist, immer false - ohne Anmeldung
  /// laesst sich ueber die Verbindung nichts aussagen.
  bool get isOffline => _angemeldet && _offline;

  /// True, wenn Aenderungen auf die Uebertragung warten.
  bool get hasPendingWrites => _angemeldet && _ausstehendeSchreibvorgaenge;

  ConnectionStatus({bool subscribe = true}) {
    if (!subscribe) return;
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _angemeldet = user != null;
      if (user == null) {
        _beendeFuehler();
        _offline = false;
        _ausstehendeSchreibvorgaenge = false;
        notifyListeners();
      } else {
        _starteFuehler();
      }
    });
  }

  void _starteFuehler() {
    _sub?.cancel();
    _retry?.cancel();
    _retry = null;
    // Eine kleine, immer vorhandene Sammlung genuegt als Fuehler.
    _sub = FirebaseFirestore.instance
        .collection('tables')
        .limit(1)
        .snapshots(includeMetadataChanges: true)
        .listen(_verarbeite, onError: _fehler);
  }

  void _beendeFuehler() {
    _sub?.cancel();
    _sub = null;
    _timer?.cancel();
    _timer = null;
    _retry?.cancel();
    _retry = null;
  }

  /// Ein Fehler im Datenstrom bedeutet nicht dauerhaft offline - er kann auch
  /// von einer gerade abgelaufenen Berechtigung kommen. Deshalb wird es
  /// spaeter erneut versucht, statt den Zustand festzuschreiben.
  void _fehler(Object e) {
    debugPrint('[ConnectionStatus] Fühler unterbrochen: $e');
    _setze(true);
    _retry ??= Timer(_neuerVersuch, () {
      _retry = null;
      if (_angemeldet) _starteFuehler();
    });
  }

  void _verarbeite(QuerySnapshot<Map<String, dynamic>> snap) {
    final ausstehend = snap.metadata.hasPendingWrites;
    if (ausstehend != _ausstehendeSchreibvorgaenge) {
      _ausstehendeSchreibvorgaenge = ausstehend;
      notifyListeners();
    }

    if (!snap.metadata.isFromCache) {
      _timer?.cancel();
      _timer = null;
      _setze(false);
      return;
    }
    // Aus dem Zwischenspeicher - abwarten, ob es dabei bleibt.
    _timer ??= Timer(_wartezeit, () => _setze(true));
  }

  void _setze(bool offline) {
    if (_offline == offline) return;
    _offline = offline;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _beendeFuehler();
    super.dispose();
  }
}
