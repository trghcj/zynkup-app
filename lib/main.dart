// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'features/auth/auth_gate.dart';
import 'core/notifications/fcm_service.dart';
import 'core/api/api_service.dart';

/// 🔔 BACKGROUND HANDLER — must be top-level function
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("🔔 Background message: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// ✅ FIREBASE INIT
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  /// 🔔 BACKGROUND HANDLER
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  /// 🔔 INIT FCM
  await FCMService().init();

  /// 🔐 LOAD SAVED TOKEN — must happen before AuthGate checks it
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
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}
