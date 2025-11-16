import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:zynkup/features/auth/screens/login_screen.dart';
import 'package:zynkup/features/events/screens/home_screen.dart';
import 'package:zynkup/firebase_options.dart';

// Global: Local Notifications
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Background Message Handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kDebugMode) {
    print('Background FCM: ${message.messageId} | Title: ${message.notification?.title}');
  }

  // Show local notification in background
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
          channelDescription: 'Event reminders and updates',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    if (kDebugMode) {
      print('Firebase initialized successfully');
    }

    // Web-specific Firestore settings
    if (kIsWeb) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
        sslEnabled: true,
      );
      if (kDebugMode) {
        print('Firestore Web settings applied');
      }
    }

    // FCM Setup
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Local Notifications Setup
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await flutterLocalNotificationsPlugin.initialize(initSettings);

    // Foreground FCM Listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final android = message.notification?.android;

      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
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

    runApp(const MyApp());
  } catch (e, s) {
    if (kDebugMode) {
      print('Firebase init failed: $e\n$s');
    }
    runApp(const MyApp());
  }
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
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _setupFCM();
  }

  Future<void> _setupFCM() async {
    final messaging = FirebaseMessaging.instance;

    // Request permission
    if (kIsWeb) {
      await messaging.requestPermission();
    } else {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (kDebugMode) {
        print('Notification permission: ${settings.authorizationStatus}');
      }
    }

    // Get FCM Token
    String? token;
    if (kIsWeb) {
      token = await messaging.getToken(
        vapidKey:
            'BJZyKjL_oOPb7-h5WJjzBQu6ofxxFuufKtiNdyYZFeI5mIkl0QV6wS3ORfIkCaBT25_X6Ux5Kr-dGBbBtXdB5NY',
      );
      if (kDebugMode && token != null) {
        print('WEB FCM Token: $token');
      }
    } else {
      token = await messaging.getToken();
      if (kDebugMode && token != null) {
        print('MOBILE FCM Token: $token');
      }
    }

    // SUBSCRIBE TO ALL USERS TOPIC
    if (token != null) {
      await messaging.subscribeToTopic('all_users');
      if (kDebugMode) {
        print('Subscribed to topic: all_users');
      }
    }

    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await messaging.subscribeToTopic('all_users');
      if (kDebugMode) {
        print('Token refreshed & resubscribed: $newToken');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.deepPurple),
                  SizedBox(height: 16),
                  Text(
                    'Zynkup Loading...',
                    style: TextStyle(fontSize: 16, color: Colors.deepPurple),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error, color: Colors.red, size: 48),
                  SizedBox(height: 16),
                  Text(
                    'Auth Error: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red),
                  ),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    child: Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasData) {
          return const HomeScreen();
        }

        return const LoginScreen();
      },
    );
  }
}