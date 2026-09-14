import 'package:flutter/foundation.dart';
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
    if (!kIsWeb) {
      await Future<void>.delayed(const Duration(milliseconds: 1000));
    }
    await ApiService.loadToken();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset('assets/logos/zynkup_logo.jpg', width: 100, height: 100),
            ),
            const SizedBox(height: 14),
             Text(
              'ZYNKUP',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
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
