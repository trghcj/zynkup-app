import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/api/api_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/widgets/theme_page_turn.dart';

import 'features/auth/screens/splash_screen.dart';
import 'firebase_options.dart';
import 'services/push_notification_service.dart';
import 'core/services/deep_link_service.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint(
    'Background notification: ${message.notification?.title ?? "Zynkup"}',
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

    await PushNotificationService.initialize();
  } catch (error) {
    debugPrint('Firebase init skipped: \$error');
  }

  runApp(const ZynkupApp());
}

class CustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

class ZynkupApp extends StatefulWidget {
  const ZynkupApp({super.key});

  @override
  State<ZynkupApp> createState() => _ZynkupAppState();
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class _ZynkupAppState extends State<ZynkupApp> {
  @override
  void initState() {
    super.initState();

    // Rebuild when theme changes so MaterialApp picks up the new ThemeMode
    themeProvider.addListener(_onThemeChange);

    // Configure and initialize deep linking
    DeepLinkService.configure(navigatorKey);
    DeepLinkService.init();

    ApiService.latestNotification.addListener(() {
      final notif = ApiService.latestNotification.value;
      if (notif != null) {
        final notifType = notif['type'] as String? ?? '';
        final isLevelUp = notifType == 'LEVEL_UP';
        final isXp = notifType == 'XP_GAINED';
        ApiService.invalidateUserCache();

        final accentColor = isLevelUp
            ? ZynkColors.gold
            : isXp
                ? ZynkColors.orange
                : ZynkColors.primary;

        final isDark = themeProvider.isDark;

        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isLevelUp
                        ? Icons.military_tech_rounded
                        : isXp
                            ? Icons.bolt_rounded
                            : Icons.notifications_active_rounded,
                    color: accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notif['title'] ?? 'Notification',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xFF0E1117),
                        ),
                      ),
                      if (notif['body'] != null &&
                          (notif['body'] as String).isNotEmpty)
                        Text(
                          notif['body'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : const Color(0xFF64748B),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            elevation: isDark ? 2 : 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: (isLevelUp || isXp)
                    ? accentColor.withValues(alpha: 0.4)
                    : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
              ),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
  }

  void _onThemeChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    themeProvider.removeListener(_onThemeChange);
    DeepLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zynkup',
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeProvider.themeMode,
      scrollBehavior: CustomScrollBehavior(),
      builder: (context, child) {
        return ThemePageTurn(child: child ?? const SizedBox.shrink());
      },
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
