import 'package:flutter/material.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/auth/screens/login_screen.dart';

class LoginPromptSheet extends StatelessWidget {
  final String message;

  const LoginPromptSheet({
    super.key,
    this.message = 'Join the campus to perform this action.',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ZynkColors.darkBg.withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: const Border(top: BorderSide(color: ZynkColors.darkBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ZynkColors.darkMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Icon(Icons.lock_rounded, size: 48, color: ZynkColors.primary),
          const SizedBox(height: 16),
          const Text(
            'Authentication Required',
            style: TextStyle(
              color: ZynkColors.offWhite,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: ZynkColors.darkMuted, fontSize: 14),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context); // Close sheet
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UserLoginScreen()),
                );
              },
              icon: const Icon(Icons.login_rounded, color: Colors.white),
              label: const Text(
                'Sign In / Register',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ZynkColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// Helper to show the sheet easily
void showLoginPrompt(BuildContext context, {String? message}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (_) => LoginPromptSheet(
      message: message ?? 'Join the campus to perform this action.',
    ),
  );
}
