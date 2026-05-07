import 'package:flutter/material.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/auth/screens/login_screen.dart';

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZynkColors.darkBg,
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.login_rounded,
              color: ZynkColors.primary,
              size: 56,
            ),
            const SizedBox(height: 18),
            const Text(
              'Use Google to join Zynkup',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ZynkColors.darkText,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'One tap creates your account and unlocks event registration, QR passes, and your dashboard.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ZynkColors.darkMuted, height: 1.45),
            ),
            const SizedBox(height: 28),
            ZynkButton(
              label: 'Continue with Google',
              icon: Icons.login_rounded,
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const UserLoginScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
