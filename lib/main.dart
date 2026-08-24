import 'dart:async';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';

import 'app.dart';
import 'state/auth_provider.dart';
import 'state/tables_provider.dart';
import 'state/events_provider.dart';
import 'state/settings_provider.dart';
import 'util/notifications_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized in background isolate
  try {
    await Firebase.initializeApp();
  } catch (_) {}

  // Crashlytics: capture Flutter errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };
  // Enable Crashlytics & Performance (no-ops on web)
  try {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
  } catch (_) {}
  try {
    await FirebasePerformance.instance.setPerformanceCollectionEnabled(true);
  } catch (_) {}
}

// Firebase background handler placeholder (will be added when enabling Firebase)

Future<void> main() async {
  // Wrap everything in runZonedGuarded from the start
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // Deutsche Datumssymbole laden - ohne das wirft jedes DateFormat
    // mit Locale 'de_DE' beim ersten Aufruf.
    await initializeDateFormatting('de_DE', null);
    // Enable immersive fullscreen on Android (hide system bars, reveal on swipe)
    try {
      if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android)) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    } catch (_) {}
    // Initialize Firebase (Android resolves options from google-services.json)
    try {
      await Firebase.initializeApp();
    } catch (_) {}

    // Enable Crashlytics & Performance collection in foreground (no-ops on web)
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    } catch (_) {}
    try {
      await FirebasePerformance.instance.setPerformanceCollectionEnabled(true);
    } catch (_) {}

    // Report uncaught Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.dumpErrorToConsole(details);
      // Use fatal for framework-level errors
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };

    // Report uncaught async/dart errors
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      // Mark fatal to ensure visibility in Crashlytics
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true; // handled
    };

    // Prepare local notifications
    final notifications = NotificationsService();
    await notifications.initialize();

    // Configure Firebase Messaging
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
      await FirebaseMessaging.instance.requestPermission();

      // Fetch and log the current FCM token (useful for testing)
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        // ignore: avoid_print
        print('FCM token: $token');
      }

      // Listen for token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        // ignore: avoid_print
        print('FCM token refreshed: $newToken');
      });

    // Foreground messages -> show local notification
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notif = message.notification;
      if (notif != null) {
        await notifications.showReady(
          notif.title ?? 'Neue Nachricht',
          notif.body ?? '',
        );
      }
    });

    // When app opened from a notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      final notif = message.notification;
      if (notif != null) {
        await notifications.showReady(
          notif.title ?? 'Benachrichtigung geöffnet',
          notif.body ?? '',
        );
      }
    });
  } catch (_) {
    // Messaging not available; continue without push
  }

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => EventsProvider()..start()),
          ChangeNotifierProvider(create: (_) => TablesProvider()),
          Provider.value(value: notifications),
          Provider.value(value: FirebaseMessaging.instance),
        ],
        child: const TsvApp(),
      ),
    );
    // Re-apply immersive mode when the app resumes
    try {
      WidgetsBinding.instance.addObserver(_ImmersiveReapplier());
    } catch (_) {}
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}

class _ImmersiveReapplier with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Best-effort reapply on Android only
      try {
        if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android)) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        }
      } catch (_) {}
    }
  }
}
