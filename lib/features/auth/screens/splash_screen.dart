import 'package:flutter/material.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/auth/screens/guest_home_screen.dart';
import 'package:zynkup/features/home/screens/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    await ApiService.loadToken();
    final user = ApiService.hasToken ? await ApiService.getCurrentUser() : null;
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            user == null ? const GuestHomeScreen() : const HomeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: ZynkColors.darkBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_rounded, color: ZynkColors.primary, size: 68),
            SizedBox(height: 14),
            Text(
              'ZYNKUP',
              style: TextStyle(
                color: ZynkColors.darkText,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Your campus, unlocked.',
              style: TextStyle(color: ZynkColors.darkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
