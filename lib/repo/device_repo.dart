import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ein Konto, das sich auf diesem Geraet ohne Passwort anmelden darf.
class StaffAccount {
  final String uid;
  final String displayName;
  final String email;
  final String role;

  const StaffAccount({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.role,
  });

  factory StaffAccount.fromMap(Map<String, dynamic> m) => StaffAccount(
        uid: (m['uid'] ?? '').toString(),
        displayName: (m['displayName'] ?? '').toString(),
        email: (m['email'] ?? '').toString(),
        role: (m['role'] ?? '').toString(),
      );

  Map<String, dynamic> toMap() =>
      {'uid': uid, 'displayName': displayName, 'email': email, 'role': role};

  String get roleLabel => switch (role) {
        'kitchen' => 'Küche',
        'bar' => 'Bar',
        'server' => 'Kellner',
        _ => role,
      };
}

/// Freischaltung dieses Geraets und die passwortlose Anmeldung darauf.
///
/// Kennung und Geheimnis liegen lokal. Das Geheimnis wird beim Freischalten
/// einmal vom Backend erzeugt und ist danach nirgends mehr abrufbar - in der
/// Datenbank steht nur seine Pruefsumme.
class DeviceRepo {
  static const _idKey = 'device.id';
  static const _secretKey = 'device.secret';
  static const _labelKey = 'device.label';
  static const _staffCacheKey = 'device.staffCache';

  final FirebaseFunctions? _injected;

  /// Erst bei Bedarf angelegt: FirebaseFunctions verlangt eine initialisierte
  /// Firebase-App, und der Anmeldebildschirm wird auch im Widget-Test gebaut,
  /// wo es keine gibt.
  FirebaseFunctions get _functions =>
      _injected ?? FirebaseFunctions.instanceFor(region: 'europe-west3');

  DeviceRepo({FirebaseFunctions? functions}) : _injected = functions;

  // ------------------------------------------------------------ Zustand

  Future<bool> isRegistered() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final id = sp.getString(_idKey);
      final secret = sp.getString(_secretKey);
      return id != null && id.isNotEmpty && secret != null && secret.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<String?> label() async {
    try {
      return (await SharedPreferences.getInstance()).getString(_labelKey);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>?> _credentials() async {
    final sp = await SharedPreferences.getInstance();
    final id = sp.getString(_idKey);
    final secret = sp.getString(_secretKey);
    if (id == null || secret == null || id.isEmpty || secret.isEmpty) return null;
    return {'deviceId': id, 'secret': secret};
  }

  // ------------------------------------------------------- Freischalten

  /// Schaltet dieses Geraet frei. Nur als Admin moeglich.
  Future<void> register(String label) async {
    final res = await _functions.httpsCallable('registerDevice').call({'label': label});
    final data = Map<String, dynamic>.from(res.data as Map);
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_idKey, (data['deviceId'] ?? '').toString());
    await sp.setString(_secretKey, (data['secret'] ?? '').toString());
    await sp.setString(_labelKey, (data['label'] ?? label).toString());
  }

  /// Entfernt die Freischaltung von diesem Geraet.
  ///
  /// Widerruft sie nicht serverseitig - dafuer gibt es [revoke]. Gedacht fuer
  /// den Fall, dass ein Geraet neu eingerichtet wird.
  Future<void> forgetLocally() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_idKey);
    await sp.remove(_secretKey);
    await sp.remove(_labelKey);
    await sp.remove(_staffCacheKey);
  }

  Future<List<Map<String, dynamic>>> listDevices() async {
    final res = await _functions.httpsCallable('listDevices').call();
    final data = Map<String, dynamic>.from(res.data as Map);
    return (data['devices'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> revoke(String deviceId) async {
    await _functions.httpsCallable('revokeDevice').call({'deviceId': deviceId});
  }

  // ------------------------------------------------------------ Anmelden

  /// Konten, die sich hier ohne Passwort anmelden duerfen.
  ///
  /// Das Ergebnis wird lokal behalten, damit die Namensliste auch dann
  /// erscheint, wenn das WLAN gerade klemmt. Die Anmeldung selbst braucht
  /// trotzdem Verbindung.
  Future<List<StaffAccount>> staffList() async {
    final cred = await _credentials();
    if (cred == null) return const [];
    try {
      final res = await _functions.httpsCallable('staffList').call(cred);
      final data = Map<String, dynamic>.from(res.data as Map);
      final users = (data['users'] as List? ?? const [])
          .map((e) => StaffAccount.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      await _cacheStaff(users);
      return users;
    } catch (_) {
      return _cachedStaff();
    }
  }

  Future<void> _cacheStaff(List<StaffAccount> users) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setStringList(
        _staffCacheKey,
        users.map((u) => '${u.uid}|${u.displayName}|${u.email}|${u.role}').toList(),
      );
    } catch (_) {}
  }

  Future<List<StaffAccount>> _cachedStaff() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final list = sp.getStringList(_staffCacheKey) ?? const [];
      return list.map((z) {
        final t = z.split('|');
        return StaffAccount(
          uid: t.isNotEmpty ? t[0] : '',
          displayName: t.length > 1 ? t[1] : '',
          email: t.length > 2 ? t[2] : '',
          role: t.length > 3 ? t[3] : '',
        );
      }).where((u) => u.uid.isNotEmpty).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Holt einen Anmeldetoken fuer ein Personalkonto.
  /// Wirft, wenn das Geraet nicht freigeschaltet ist oder das Konto ein
  /// Adminkonto ist.
  Future<String> signInToken(String uid) async {
    final cred = await _credentials();
    if (cred == null) {
      throw Exception('Dieses Gerät ist nicht freigeschaltet.');
    }
    final res = await _functions.httpsCallable('staffSignIn').call({...cred, 'uid': uid});
    final data = Map<String, dynamic>.from(res.data as Map);
    final token = (data['token'] ?? '').toString();
    if (token.isEmpty) throw Exception('Kein Anmeldetoken erhalten.');
    return token;
  }
}
