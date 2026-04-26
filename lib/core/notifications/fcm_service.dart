import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class FCMService {
  static final FirebaseMessaging _messaging =
      FirebaseMessaging.instance;

  /// 🔥 GLOBAL NAVIGATOR KEY
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// 🔥 INIT
  Future<void> init() async {
    /// Request permission
    await _messaging.requestPermission();

    /// 🔥 GET DEVICE TOKEN (IMPORTANT)
    final token = await _messaging.getToken();
    debugPrint("FCM Token: $token");

    /// 👉 Send this token to your FastAPI backend
    /// Example:
    /// POST /users/save-token

    /// 🔔 FOREGROUND
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint("Foreground: ${message.notification?.title}");
    });

    /// 🔔 CLICK (BACKGROUND)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleClick);

    /// 🔔 CLICK (TERMINATED)
    final initialMessage =
        await _messaging.getInitialMessage();

    if (initialMessage != null) {
      _handleClick(initialMessage);
    }
  }

  // ================= CLICK HANDLER =================
  void _handleClick(RemoteMessage message) {
    final data = message.data;
    final eventId = data['eventId'];

    if (eventId == null) return;

    navigatorKey.currentState?.pushNamed(
      '/event',
      arguments: eventId,
    );
  }
}