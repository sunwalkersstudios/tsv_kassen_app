import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Geraetesperre der App.
///
/// Bisher verlangte der Sperrbildschirm einen Fingerabdruck und entsperrte sich
/// auf Geraeten ohne Biometrie sofort selbst - die Sperre war dort wirkungslos.
/// Als Rueckfallebene gibt es jetzt eine PIN.
///
/// Die PIN gilt pro Geraet und liegt nur lokal. Sie schuetzt das Tablet im
/// laufenden Betrieb, nicht das Konto - die eigentliche Anmeldung bleibt
/// E-Mail und Passwort.
///
/// Gespeichert wird nur ein gesalzener SHA-256-Wert, nie die PIN selbst.
class AppLock {
  AppLock._();

  static const _hashKey = 'lock.pinHash';
  static const _saltKey = 'lock.pinSalt';
  static const minLength = 4;
  static const maxLength = 8;

  static String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt::$pin')).toString();

  static String _newSalt() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// True, wenn auf diesem Geraet eine PIN hinterlegt ist.
  static Future<bool> hasPin() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final h = sp.getString(_hashKey);
      return h != null && h.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Legt eine PIN an oder ersetzt sie. Gibt eine Fehlermeldung zurueck,
  /// wenn die Eingabe nicht taugt, sonst null.
  static Future<String?> setPin(String pin) async {
    final trimmed = pin.trim();
    if (trimmed.length < minLength || trimmed.length > maxLength) {
      return 'Die PIN muss zwischen $minLength und $maxLength Ziffern haben.';
    }
    if (!RegExp(r'^\d+$').hasMatch(trimmed)) {
      return 'Die PIN darf nur Ziffern enthalten.';
    }
    if (RegExp(r'^(\d)\1+$').hasMatch(trimmed)) {
      return 'Bitte keine PIN aus lauter gleichen Ziffern.';
    }
    try {
      final sp = await SharedPreferences.getInstance();
      final salt = _newSalt();
      await sp.setString(_saltKey, salt);
      await sp.setString(_hashKey, _hash(trimmed, salt));
      return null;
    } catch (e) {
      return 'PIN konnte nicht gespeichert werden.';
    }
  }

  /// Prueft eine eingegebene PIN.
  static Future<bool> verify(String pin) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final salt = sp.getString(_saltKey);
      final hash = sp.getString(_hashKey);
      if (salt == null || hash == null) return false;
      return _hash(pin.trim(), salt) == hash;
    } catch (_) {
      return false;
    }
  }

  /// Entfernt die PIN von diesem Geraet.
  static Future<void> clearPin() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_hashKey);
      await sp.remove(_saltKey);
    } catch (_) {}
  }
}
