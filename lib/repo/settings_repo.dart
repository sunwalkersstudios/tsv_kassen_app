import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../state/device_context.dart';

class SettingsRepo {
  final _db = FirebaseFirestore.instance;

  Future<String?> _orgIdOrFallback() async {
    final orgId = DeviceContext.deviceOrgId;
    if (orgId != null && orgId.isNotEmpty) return orgId;
    try {
      final snap = await _db.collection('orgs').limit(1).get();
      if (snap.docs.isNotEmpty) {
        final id = snap.docs.first.id;
        // update DeviceContext for future calls
        DeviceContext.deviceOrgId = id;
        final name = (snap.docs.first.data()['name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) {
          DeviceContext.deviceOrgName = name;
        }
        return id;
      }
    } catch (_) {}
    return null;
  }

  Stream<Map<String, dynamic>> streamOrgSettings() {
    final orgId = DeviceContext.deviceOrgId;
    if (orgId != null && orgId.isNotEmpty) {
      return _db.collection('orgs').doc(orgId).snapshots().map((snap) => (snap.data() ?? const {}));
    }
    // Fallback: single-tenant default to first org document
    return _db.collection('orgs').limit(1).snapshots().map((qs) {
      if (qs.docs.isEmpty) return const {};
      final d = qs.docs.first;
      // Cache for later
      DeviceContext.deviceOrgId = d.id;
      final name = (d.data()['name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) DeviceContext.deviceOrgName = name;
      return d.data();
    });
  }

  Future<void> setMergeKitchenBar(bool value) async {
    final orgId = await _orgIdOrFallback();
    if (orgId == null || orgId.isEmpty) return;
    await _db.collection('orgs').doc(orgId).set({'mergeKitchenBar': value}, SetOptions(merge: true));
    // Cache locally for instant checks (e.g., login routing)
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool('mergeKitchenBar', value);
    } catch (_) {}
  }

  Future<bool> getMergeKitchenBar() async {
    // Prefer local cache for fast path
    try {
      final sp = await SharedPreferences.getInstance();
      final cached = sp.getBool('mergeKitchenBar');
      if (cached != null) return cached;
    } catch (_) {}
    final orgId = DeviceContext.deviceOrgId;
    if (orgId == null || orgId.isEmpty) return false;
    final snap = await _db.collection('orgs').doc(orgId).get();
    final data = snap.data() ?? const {};
    final v = data['mergeKitchenBar'] == true;
    // Refresh cache
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool('mergeKitchenBar', v);
    } catch (_) {}
    return v;
  }

  Future<Map<String, dynamic>> getPrinter(String type) async {
    final orgId = await _orgIdOrFallback();
    if (orgId == null || orgId.isEmpty) return const {};
    final snap = await _db.collection('orgs').doc(orgId).get();
    final data = snap.data() ?? const {};
    final key = type == 'cashier' ? 'printerCashier' : 'printerBon';
    if (data[key] is Map) return Map<String, dynamic>.from(data[key] as Map);
    return const {};
  }

  Future<void> setPrinter(String type, {required String ip, required int port, required int cols, required String mode}) async {
    final orgId = await _orgIdOrFallback();
    if (orgId == null || orgId.isEmpty) return;
    final key = type == 'cashier' ? 'printerCashier' : 'printerBon';
    await _db.collection('orgs').doc(orgId).set({
      key: {
        'ip': ip,
        'port': port,
        'cols': cols,
        'mode': mode,
      }
    }, SetOptions(merge: true));
  }

  /// Returns templates for the given type ('cashier' or 'bon').
  /// Structure: { 'header': String, 'item': String, 'footer': String, 'hospitality': String }
  Future<Map<String, String>> getTemplates(String type) async {
    final orgId = await _orgIdOrFallback();
    if (orgId == null || orgId.isEmpty) return const {};
    final snap = await _db.collection('orgs').doc(orgId).get();
    final data = snap.data() ?? const {};
    // Support either flat keys or nested under 'templates'
    final key = type == 'cashier' ? 'templatesCashier' : 'templatesBon';
    Map<String, dynamic>? src;
    if (data[key] is Map) {
      src = Map<String, dynamic>.from(data[key] as Map);
    } else if (data['templates'] is Map) {
      final t = Map<String, dynamic>.from(data['templates'] as Map);
      if (t[type] is Map) src = Map<String, dynamic>.from(t[type] as Map);
    }
    if (src == null) return const {};
    return {
      'header': (src['header'] ?? '').toString(),
      'item': (src['item'] ?? '').toString(),
      'footer': (src['footer'] ?? '').toString(),
      'hospitality': (src['hospitality'] ?? '').toString(),
    };
  }

  /// Saves templates for the given type ('cashier' or 'bon').
  Future<void> setTemplates(String type, Map<String, String> templates) async {
    final orgId = await _orgIdOrFallback();
    if (orgId == null || orgId.isEmpty) return;
    final key = type == 'cashier' ? 'templatesCashier' : 'templatesBon';
    await _db.collection('orgs').doc(orgId).set({
      key: templates,
    }, SetOptions(merge: true));
  }
}