import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../state/device_context.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _db = FirebaseFirestore.instance;
  final _fx = FirebaseFunctions.instanceFor(region: 'europe-west3');

  Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream() {
    final orgId = DeviceContext.deviceOrgId;
    Query<Map<String, dynamic>> q = _db.collection('users');
    if (orgId != null && orgId.isNotEmpty) {
      q = q.where('orgId', isEqualTo: orgId);
    }
    return q.orderBy('email').snapshots();
  }

  Future<List<Map<String, dynamic>>> _fallbackUsersList({int limit = 200}) async {
    try {
      final res = await _fx.httpsCallable('adminListUsers').call({'limit': limit});
      final data = Map<String, dynamic>.from(res.data as Map);
      final list = (data['users'] as List<dynamic>? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      // sort by email for stable order
      list.sort((a, b) => (a['email'] ?? '').toString().compareTo((b['email'] ?? '').toString()));
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _createUserDialog() async {
    String role = 'server';
    final emailCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final pwCtrl = TextEditingController();
    final useAutoEmail = ValueNotifier<bool>(true);
    final useAutoPw = ValueNotifier<bool>(true);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDlg) => AlertDialog(
          title: const Text('Benutzer anlegen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('Rolle:'),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: role,
                    items: const [
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      DropdownMenuItem(value: 'server', child: Text('Kellner')),
                      DropdownMenuItem(value: 'kitchen', child: Text('Küche')),
                      DropdownMenuItem(value: 'bar', child: Text('Bar')),
                    ],
                    onChanged: (v) { if (v != null) setStateDlg(() => role = v); },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(child: Text('E-Mail automatisch (<rolle>@<org>.local)')),
                  ValueListenableBuilder<bool>(
                    valueListenable: useAutoEmail,
                    builder: (_, v, __) => Switch(value: v, onChanged: (x) => useAutoEmail.value = x),
                  ),
                ],
              ),
              if (!useAutoEmail.value)
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'E-Mail')),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Anzeigename')),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(child: Text('Passwort automatisch (zufällig)')),
                  ValueListenableBuilder<bool>(
                    valueListenable: useAutoPw,
                    builder: (_, v, __) => Switch(value: v, onChanged: (x) => useAutoPw.value = x),
                  ),
                ],
              ),
              if (!useAutoPw.value)
                TextField(controller: pwCtrl, decoration: const InputDecoration(labelText: 'Passwort (min. 8)'), obscureText: true),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Anlegen')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final callable = _fx.httpsCallable('adminCreateUser');
      final res = await callable.call({
        'role': role,
        if (!useAutoEmail.value && emailCtrl.text.trim().isNotEmpty) 'email': emailCtrl.text.trim(),
        if (nameCtrl.text.trim().isNotEmpty) 'displayName': nameCtrl.text.trim(),
        if (!useAutoPw.value && pwCtrl.text.trim().length >= 8) 'password': pwCtrl.text.trim(),
      });
      final data = Map<String, dynamic>.from(res.data as Map);
      final email = data['email']?.toString() ?? '(ohne)';
      final tempPw = data['tempPassword']?.toString();
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Benutzer angelegt'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('E-Mail:'),
              const SizedBox(height: 4),
              SelectableText(email, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              if (tempPw != null) ...[
                const Text('Initiales Passwort:'),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(child: SelectableText(tempPw, style: const TextStyle(fontWeight: FontWeight.w600))),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: 'Passwort kopieren',
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: tempPw));
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwort kopiert')));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Hinweis: Passwort wird aus Sicherheitsgründen nicht gespeichert. Bitte jetzt notieren.'),
              ],
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  Future<void> _setRole(String uid, String role) async {
    try {
      await _fx.httpsCallable('adminSetRole').call({'uid': uid, 'role': role});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rollenwechsel fehlgeschlagen: $e')));
    }
  }

  Future<void> _setDisabled(String uid, bool disabled) async {
    try {
      await _fx.httpsCallable('adminDisableUser').call({'uid': uid, 'disabled': disabled});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Aktualisierung fehlgeschlagen: $e')));
    }
  }

  Future<void> _setPassword(String uid) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Passwort setzen'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Neues Passwort (min. 8)'), obscureText: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Speichern')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().length >= 8) {
      try {
        await _fx.httpsCallable('adminSetPassword').call({'uid': uid, 'password': ctrl.text.trim()});
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwort aktualisiert')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  Future<void> _editDisplayName(String uid, String current) async {
    final ctrl = TextEditingController(text: current);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Namen bearbeiten'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Anzeigename')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Speichern')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      try {
        await _db.collection('users').doc(uid).set({'displayName': ctrl.text.trim()}, SetOptions(merge: true));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler beim Speichern: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Benutzerverwaltung')),
      floatingActionButton: FloatingActionButton(
        onPressed: _createUserDialog,
        child: const Icon(Icons.person_add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _usersStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            final err = snap.error.toString();
            // Friendly fallback while composite index is building
            if (err.contains('failed-precondition') && err.contains('requires an index')) {
              return FutureBuilder<List<Map<String, dynamic>>>(
                future: _fallbackUsersList(),
                builder: (ctx, fb) {
                  if (fb.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = fb.data ?? const [];
                  if (items.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Index wird erstellt …', style: TextStyle(fontWeight: FontWeight.w600)),
                          SizedBox(height: 8),
                          Text('Die Benutzerliste wird verfügbar, sobald der Firestore-Index gebaut ist (meist < 2 Minuten).'),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final m = items[i];
                      final email = (m['email'] ?? '').toString();
                      final displayName = (m['displayName'] ?? '').toString();
                      final role = (m['role'] ?? 'server').toString();
                      final disabled = (m['disabled'] == true);
                      final uid = (m['id'] ?? '').toString();
                      final isAdmin = role == 'admin';
                      final isSelf = (currentUid != null && uid == currentUid);
                      final active = !disabled;
                      return ListTile(
                        title: Text(displayName.isNotEmpty ? displayName : email),
                        subtitle: Text(email),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DropdownButton<String>(
                              value: role,
                              items: const [
                                DropdownMenuItem(value: 'admin', child: Text('Admin')),
                                DropdownMenuItem(value: 'server', child: Text('Kellner')),
                                DropdownMenuItem(value: 'kitchen', child: Text('Küche')),
                                DropdownMenuItem(value: 'bar', child: Text('Bar')),
                              ],
                              onChanged: (v) { if (v != null) _setRole(uid, v); },
                            ),
                            const SizedBox(width: 12),
                            if (!isAdmin)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Aktiv'),
                                  const SizedBox(width: 6),
                                  Switch(
                                    value: active,
                                    onChanged: (v) {
                                      if (isSelf) return; // prevent self-disable
                                      _setDisabled(uid, !v); // store as disabled flag
                                    },
                                  ),
                                ],
                              ),
                            IconButton(icon: const Icon(Icons.edit), tooltip: 'Namen ändern', onPressed: () => _editDisplayName(uid, displayName.isNotEmpty ? displayName : email)),
                            IconButton(icon: const Icon(Icons.password), tooltip: 'Passwort setzen', onPressed: () => _setPassword(uid)),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            }
            return Center(child: Text('Fehler: ${snap.error}'));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Noch keine Benutzer'));
          }
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = docs[i];
              final m = d.data();
              final email = (m['email'] ?? '').toString();
              final displayName = (m['displayName'] ?? '').toString();
              final role = (m['role'] ?? 'server').toString();
              final disabled = (m['disabled'] == true);
              final isAdmin = role == 'admin';
              final isSelf = (currentUid != null && d.id == currentUid);
              final active = !disabled;
              return ListTile(
                title: Text(displayName.isNotEmpty ? displayName : email),
                subtitle: Text(email),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButton<String>(
                      value: role,
                      items: const [
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                        DropdownMenuItem(value: 'server', child: Text('Kellner')),
                        DropdownMenuItem(value: 'kitchen', child: Text('Küche')),
                        DropdownMenuItem(value: 'bar', child: Text('Bar')),
                      ],
                      onChanged: (v) { if (v != null) _setRole(d.id, v); },
                    ),
                    const SizedBox(width: 12),
                    if (!isAdmin)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Aktiv'),
                          const SizedBox(width: 6),
                          Switch(
                            value: active,
                            onChanged: (v) {
                              if (isSelf) return; // prevent self-disable
                              _setDisabled(d.id, !v);
                            },
                          ),
                        ],
                      ),
                    IconButton(icon: const Icon(Icons.edit), tooltip: 'Namen ändern', onPressed: () => _editDisplayName(d.id, displayName.isNotEmpty ? displayName : email)),
                    IconButton(icon: const Icon(Icons.password), tooltip: 'Passwort setzen', onPressed: () => _setPassword(d.id)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
