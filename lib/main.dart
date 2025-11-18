// lib/main.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:zynkup/features/auth/screens/login_choice_screen.dart';
import 'package:zynkup/features/events/screens/home_screen.dart';  // SINGLE HOME SCREEN FOR ALL
import 'package:zynkup/firebase_options.dart';

// Global Notification Plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Background Message Handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final notification = message.notification;
  if (notification != null) {
    await flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'zynkup_channel',
          'Zynkup Events',
          channelDescription: 'Event reminders & updates',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: androidInit, iOS: iosInit),
  );

  // Foreground notifications
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'zynkup_channel',
            'Zynkup Events',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
        ),
      );
    }
  });

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const AuthGate(),
      // Removed routes — not needed anymore
    );
  }
}

// MAIN AUTH GATE — ONLY DECIDES IF LOGGED IN OR NOT
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  // LIST OF ADMIN EMAILS — USED IN home_screen.dart ALSO
  static const List<String> adminEmails = [
    'admin@zynkup.com',
    'cdc@mait.ac.in',
    'faculty@mait.ac.in',
    'organizer@gmail.com',
    'admin@gmail.com',
    'your-admin@gmail.com', // ADD YOUR EMAIL HERE
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.deepPurple),
                  SizedBox(height: 24),
                  Text('Zynkup Loading...', style: TextStyle(fontSize: 18)),
                ],
              ),
            ),
          );
        }

        // LOGGED IN → SAME SCREEN FOR EVERYONE
        if (snapshot.hasData) {
          return const HomeScreen(); // ONE SCREEN HANDLES BOTH ADMIN & USER
        }

        // NOT LOGGED IN → SHOW CHOICE
        return const LoginChoiceScreen();
      },
    );
  }
}