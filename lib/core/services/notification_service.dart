// lib/features/notifications/notification_service.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FirebaseMessaging _messaging =
      FirebaseMessaging.instance;

  static final FlutterLocalNotificationsPlugin
      _localNotifications = FlutterLocalNotificationsPlugin();

  // ============================
  // ANDROID NOTIFICATION CHANNEL
  // ============================
  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
    'zynkup_channel',
    'Zynkup Events',
    description: 'Event reminders and updates',
    importance: Importance.high,
  );

  // ============================
  // INIT
  // ============================
  static Future<void> init() async {
    // ----------------------------
    // REQUEST PERMISSIONS
    // ----------------------------
    if (!kIsWeb) {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // ----------------------------
    // LOCAL NOTIFICATION INIT
    // ----------------------------
    if (!kIsWeb) {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initSettings =
          InitializationSettings(android: androidSettings);

      await _localNotifications.initialize(initSettings);
    }

    // ----------------------------
    // ANDROID CHANNEL
    // ----------------------------
    if (!kIsWeb) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
    }

    // ----------------------------
    // FCM TOKEN (DEBUG ONLY)
    // ----------------------------
    try {
      final token = await _messaging.getToken();
      if (kDebugMode && token != null) {
        // ignore: avoid_print
        print('🔥 FCM Token: $token');
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('❌ Failed to get FCM token');
      }
    }

    // ----------------------------
    // FOREGROUND HANDLER
    // ----------------------------
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
  }

  // ============================
  // FOREGROUND NOTIFICATION
  // ============================
  static void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final android = notification?.android;

    if (notification == null) return;

    // Web → browser handles it
    if (kIsWeb) return;

    if (android != null) {
      _localNotifications.show(
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
  }
}
