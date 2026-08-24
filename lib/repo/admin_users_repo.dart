import 'package:cloud_functions/cloud_functions.dart';

class AdminUsersRepo {
  final FirebaseFunctions _functions;
  AdminUsersRepo({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');

  Future<Map<String, dynamic>> createInternalUser({required String role, String? email, String? displayName}) async {
    final callable = _functions.httpsCallable('adminCreateUser');
    final res = await callable.call({
      'role': role,
      if (email != null) 'email': email,
      if (displayName != null) 'displayName': displayName,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> setRole({required String uid, required String role}) async {
    final callable = _functions.httpsCallable('adminSetRole');
    await callable.call({'uid': uid, 'role': role});
  }

  Future<void> setDisabled({required String uid, required bool disabled}) async {
    final callable = _functions.httpsCallable('adminDisableUser');
    await callable.call({'uid': uid, 'disabled': disabled});
  }

  Future<void> setPassword({required String uid, required String password}) async {
    final callable = _functions.httpsCallable('adminSetPassword');
    await callable.call({'uid': uid, 'password': password});
  }
}
