import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/connection_status.dart';

/// Zeigt an, wenn die App ohne Verbindung arbeitet.
///
/// Bleibt unsichtbar, solange alles laeuft - ein staendig praesentes
/// "verbunden" waere nur Rauschen. Sichtbar wird es genau dann, wenn jemand es
/// wissen muss: wenn Bestellungen auf dem Geraet warten, statt in der Kueche zu
/// liegen.
class ConnectionIndicator extends StatelessWidget {
  const ConnectionIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.watch<ConnectionStatus>();
    if (!status.isOffline && !status.hasPendingWrites) {
      return const SizedBox.shrink();
    }

    final t = Theme.of(context);
    final cs = t.colorScheme;
    final offline = status.isOffline;

    final farbe = offline ? cs.error : cs.tertiary;
    final text = offline ? 'Offline' : 'Wird gesendet';
    final icon = offline ? Icons.cloud_off : Icons.cloud_upload;

    return Tooltip(
      message: offline
          ? 'Keine Verbindung. Bestellungen werden gespeichert und automatisch '
              'nachgereicht, sobald das WLAN wieder da ist.'
          : 'Änderungen werden gerade übertragen.',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: farbe.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: farbe),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: farbe),
            const SizedBox(width: 6),
            Text(text,
                style: t.textTheme.bodySmall
                    ?.copyWith(color: farbe, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
