import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/entities.dart';
import '../state/auth_provider.dart';

/// Zeigt den angemeldeten Nutzer und bietet den Wechsel an.
///
/// Ersetzt den frueheren schwebenden Knopf, der in `app.dart` ueber jeden
/// Bildschirm gelegt wurde: dafuer steckte dort ein zweiter Navigator im
/// `builder` von `MaterialApp.router`, der zwei Navigationssysteme ineinander
/// verschachtelte und den Knopf ueber alle Inhalte legte. Als AppBar-Element
/// gehoert er dorthin, wo Nutzer ihn erwarten.
class UserMenuButton extends StatelessWidget {
  const UserMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    if (user == null) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return PopupMenuButton<String>(
      tooltip: 'Angemeldet als ${user.displayName}',
      position: PopupMenuPosition.under,
      onSelected: (value) {
        if (value == 'switch') {
          context.read<AuthProvider>().logout();
          GoRouter.of(context).go('/login');
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(user.displayName, style: theme.textTheme.titleMedium),
              Text(_roleLabel(user.role), style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'switch',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.switch_account),
            title: Text('Nutzer wechseln'),
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                _initials(user.displayName),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'[\s._-]+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  static String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.kitchen:
        return 'Küche';
      case UserRole.bar:
        return 'Bar';
      case UserRole.server:
        return 'Kellner';
    }
  }
}
