import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationsService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
  }

  Future<void> showReady(String title, String body) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'ready_channel',
        'Ticket Ready',
        channelDescription: 'Benachrichtigung wenn Position/Ticket bereit ist',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(0, title, body, details);
  }
}
