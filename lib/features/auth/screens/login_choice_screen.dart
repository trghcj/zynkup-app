// lib/features/auth/screens/login_choice_screen.dart
import 'package:flutter/material.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/admin/screens/admin_login_screen.dart';
import 'package:zynkup/features/auth/screens/signup_screen.dart';
import 'package:zynkup/features/user/screens/user_login_screen.dart';

class LoginChoiceScreen extends StatelessWidget {
  const LoginChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ── Background ────────────────────────────────────
          Container(
            decoration: const BoxDecoration(gradient: ZynkGradients.warmDark),
          ),

          // ── Decorative circles ────────────────────────────
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ZynkColors.primary.withOpacity(0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ZynkColors.accent.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            top: size.height * 0.35,
            left: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ZynkColors.terra2.withOpacity(0.08),
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 2),

                  // ── Logo block ────────────────────────────
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: ZynkGradients.brand,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: ZynkColors.primary.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.bolt_rounded,
                        color: Colors.white, size: 32),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'ZYNKUP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2,
                      height: 1,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Row(children: [
                    Container(
                      width: 32,
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: ZynkGradients.gold,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'MAIT Event Platform',
                      style: TextStyle(
                        color: ZynkColors.darkMuted,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ]),

                  const Spacer(flex: 3),

                  // ── Buttons ───────────────────────────────
                  _LoginTile(
                    icon: Icons.admin_panel_settings_rounded,
                    label: 'Admin / Organizer',
                    sublabel: 'Manage events & users',
                    gradient: ZynkGradients.brand,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminLoginScreen()),
                    ),
                  ),

                  const SizedBox(height: 14),

                  _LoginTile(
                    icon: Icons.school_rounded,
                    label: 'Student / Guest',
                    sublabel: 'Browse & register for events',
                    outlined: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const UserLoginScreen()),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Signup ────────────────────────────────
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SignUpScreen()),
                      ),
                      child: RichText(
                        text: const TextSpan(
                          text: 'New here? ',
                          style: TextStyle(
                              color: ZynkColors.darkMuted, fontSize: 14),
                          children: [
                            TextSpan(
                              text: 'Create an account →',
                              style: TextStyle(
                                color: ZynkColors.accentLight,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Gradient? gradient;
  final bool outlined;
  final VoidCallback onTap;

  const _LoginTile({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.onTap,
    this.gradient,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          gradient: outlined ? null : gradient,
          borderRadius: BorderRadius.circular(16),
          border: outlined
              ? Border.all(color: ZynkColors.darkBorder, width: 1.5)
              : null,
          color: outlined ? ZynkColors.darkSurface : null,
          boxShadow: outlined
              ? null
              : [
                  BoxShadow(
                    color: ZynkColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: outlined
                    ? ZynkColors.darkSurface2
                    : Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  color: outlined ? ZynkColors.primary : Colors.white,
                  size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color:
                          outlined ? ZynkColors.darkText : Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sublabel,
                    style: TextStyle(
                      color: outlined
                          ? ZynkColors.darkMuted
                          : Colors.white.withOpacity(0.75),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: outlined
                  ? ZynkColors.darkMuted
                  : Colors.white.withOpacity(0.7),
            ),
          ],
        ),
      ),
    );
  }
}