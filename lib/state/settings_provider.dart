import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repo/settings_repo.dart';

class SettingsProvider extends ChangeNotifier {
  final _repo = SettingsRepo();
  bool _mergeKitchenBar = false;
  bool get mergeKitchenBar => _mergeKitchenBar;

  StreamSubscription<Map<String, dynamic>>? _sub;

  SettingsProvider() {
    _seedFromCache();
    _sub = _repo.streamOrgSettings().listen((data) async {
      final v = data['mergeKitchenBar'] == true;
      if (v != _mergeKitchenBar) {
        _mergeKitchenBar = v;
        // keep cache in sync
        try {
          final sp = await SharedPreferences.getInstance();
          await sp.setBool('mergeKitchenBar', v);
        } catch (_) {}
        notifyListeners();
      }
    }, onError: (_) {});
  }

  Future<void> _seedFromCache() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final cached = sp.getBool('mergeKitchenBar');
      if (cached != null) {
        _mergeKitchenBar = cached;
        notifyListeners();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    super.dispose();
  }
}
