import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/api/api_service.dart';
import 'core/theme/app_theme.dart';

import 'features/auth/screens/splash_screen.dart';
import 'firebase_options.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint(
    'Background notification: ${message.notification?.title ?? 'Zynkup'}',
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.loadToken();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Register FCM Token
    final token = await messaging.getToken();
    if (token != null) {
       ApiService.registerFcmToken(token);
    }
    messaging.onTokenRefresh.listen((newToken) {
       ApiService.registerFcmToken(newToken);
    });

  } catch (error) {
    debugPrint('Firebase init skipped: $error');
  }

  runApp(const ZynkupApp());
}

class ZynkupApp extends StatefulWidget {
  const ZynkupApp({super.key});

  @override
  State<ZynkupApp> createState() => _ZynkupAppState();
}

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class _ZynkupAppState extends State<ZynkupApp> {
  @override
  void initState() {
    super.initState();
    
    ApiService.latestNotification.addListener(() {
      final notif = ApiService.latestNotification.value;
      if (notif != null) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text("${notif['title'] ?? 'Notification'}: ${notif['body'] ?? ''}"),
            behavior: SnackBarBehavior.floating,
            backgroundColor: ZynkColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zynkup',
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const SplashScreen(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const ZynkupApp();
  }
}
