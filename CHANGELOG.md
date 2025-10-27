# Changelog

## 1.0.2+4 — 2025-10-27

- Build stabilisiert und Lint-Probleme behoben
  - use_build_context_synchronously in mehreren Screens gefixt (Admin*, Cashier, Order)
  - Deprecated `.withOpacity(...)` durch `.withValues(alpha: ...)` ersetzt (TablePlan)
- Dependency-Upgrades
  - firebase_core ^4.2.0, firebase_auth ^6.1.1, cloud_firestore ^6.0.3, firebase_messaging ^16.0.3
  - firebase_crashlytics ^5.0.3, firebase_performance ^0.11.1+1
  - go_router 16.3.0, local_auth 3.0.0
- Tests/Analyse/Build
  - `flutter analyze`: keine Fehler
  - `flutter test`: grün (+1)
  - Release-Build (APK) erfolgreich

Hinweis: Weitere optionale Upgrades (z. B. flutter_local_notifications, lints) sind möglich, aber nicht Teil dieses Freeze-Releases.
