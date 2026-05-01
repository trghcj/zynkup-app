// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

import 'features/auth/auth_gate.dart';
import 'core/api/api_service.dart';
import 'core/theme/app_theme.dart';

/// Background handler — must be top-level
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("🔔 Background: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Firebase init ──────────────────────────────────────────────────────────
  // Wrapped in try/catch so a Firebase error never causes white screen
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request notification permission — don't crash if denied
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true, badge: true, sound: true,
      );
    } catch (_) {
      // Permission denied — that's fine, app still works
    }

    // Get FCM token silently — don't block startup
    FirebaseMessaging.instance.getToken().then((token) {
      if (token != null) debugPrint("FCM Token: $token");
    }).catchError((_) {});

  } catch (e) {
    // Firebase failed (e.g. missing google-services, no internet) — keep going
    debugPrint("Firebase init failed: $e — continuing without FCM");
  }

  // ── Load saved auth token ──────────────────────────────────────────────────
  await ApiService.loadToken();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zynkup',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system, // auto dark/light
      home: const AuthGate(),
    );
  }
}