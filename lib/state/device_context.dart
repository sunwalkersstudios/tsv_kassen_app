import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight per-device context used by login/onboarding flows.
///
/// In production this may be populated during onboarding; for tests and
/// offline development, defaults are null and the API is safe to call.
class DeviceContext {
  static String? deviceOrgId;
  static String? deviceOrgName;

  /// Clears any cached device context and related local preferences.
  static Future<void> clear() async {
    deviceOrgId = null;
    deviceOrgName = null;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove('deviceOrgId');
      await sp.remove('deviceOrgName');
      // Also clear any org-scoped cached emails if present
      // Note: We don't know the current org key when clearing; callers may
      // manage specific keys like 'knownEmails:<orgId>' separately.
    } catch (_) {}
  }
}
