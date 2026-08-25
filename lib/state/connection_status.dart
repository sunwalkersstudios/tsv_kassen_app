import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Meldet, ob die App gerade Verbindung zu Firestore hat.
///
/// Firestore arbeitet offline weiter: Lesezugriffe kommen aus dem
/// Zwischenspeicher, Schreibzugriffe warten und werden nachgereicht, sobald es
/// wieder geht. Das ist im Vereinsheim mit wackeligem WLAN genau richtig - hat
/// aber eine Tuecke: Ohne Hinweis glaubt der Kellner, die Bestellung liege in
/// der Kueche, waehrend sie noch auf dem Geraet wartet.
///
/// Erkannt wird der Zustand ueber die Herkunft der Daten. Kommt ein Schnappschuss
/// aus dem Zwischenspeicher statt vom Server, ist die Verbindung vermutlich weg.
/// Kurze Aussetzer sind normal, deshalb gilt die Verbindung erst nach
/// [_wartezeit] als unterbrochen - sonst blinkt der Hinweis staendig auf.
class ConnectionStatus extends ChangeNotifier {
  static const _wartezeit = Duration(seconds: 4);

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  Timer? _timer;

  bool _offline = false;
  bool _ausstehendeSchreibvorgaenge = false;

  /// True, wenn seit mehreren Sekunden nur noch Daten aus dem Zwischenspeicher
  /// kommen.
  bool get isOffline => _offline;

  /// True, wenn Aenderungen auf die Uebertragung warten.
  bool get hasPendingWrites => _ausstehendeSchreibvorgaenge;

  ConnectionStatus({bool subscribe = true}) {
    if (!subscribe) return;
    // Eine kleine, immer vorhandene Sammlung genuegt als Fuehler.
    _sub = FirebaseFirestore.instance
        .collection('tables')
        .limit(1)
        .snapshots(includeMetadataChanges: true)
        .listen(_verarbeite, onError: (_) => _setze(true));
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
    _timer?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
