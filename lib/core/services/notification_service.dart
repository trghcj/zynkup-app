import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'; // ADD THIS LINE
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Import the global instance from main.dart
import '../../main.dart' show flutterLocalNotificationsPlugin;

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> init() async {
    // Request permission (iOS + Android)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Safe debug logging
    if (kDebugMode) {
      // ignore: avoid_print
      print('Notification permission: ${settings.authorizationStatus}');
    }

    // Get FCM Token
    String? token = await _messaging.getToken();
    if (kDebugMode && token != null) {
      // ignore: avoid_print
      print('FCM Token: $token');
    }

    // Foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final android = message.notification?.android;

      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'zynkup_channel',
              'Zynkup Events',
              channelDescription: 'Event reminders and updates',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      }
    });
  }
}