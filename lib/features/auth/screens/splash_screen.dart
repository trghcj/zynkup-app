import 'package:flutter/material.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
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
    // await Future<void>.delayed(const Duration(milliseconds: 900)); // Delay removed for instant startup
    await ApiService.loadToken();
    if (ApiService.hasToken) {
      await ApiService.getCurrentUser();
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZynkColors.darkBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset('assets/logos/zynkup_logo.jpg', width: 100, height: 100),
            ),
            const SizedBox(height: 14),
            const Text(
              'ZYNKUP',
              style: TextStyle(
                color: ZynkColors.darkText,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your campus, unlocked.',
              style: TextStyle(color: ZynkColors.darkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
