// lib/features/user/screens/user_login_screen.dart
import 'package:flutter/material.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/auth/screens/signup_screen.dart';
import 'package:zynkup/features/user/screens/user_home_screen.dart';
import 'package:zynkup/features/admin/screens/admin_home_screen.dart';

class UserLoginScreen extends StatefulWidget {
  const UserLoginScreen({super.key});

  @override
  State<UserLoginScreen> createState() => _UserLoginScreenState();
}

class _UserLoginScreenState extends State<UserLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  bool _loading = false;
  bool _hidePass = true;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final res = await ApiService.login(
          _emailC.text.trim(), _passC.text.trim());
      if (!mounted) return;
      if (res["role"] == "admin") {
        Navigator.pushAndRemoveUntil(context,
            MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
            (_) => false);
      } else {
        Navigator.pushAndRemoveUntil(context,
            MaterialPageRoute(builder: (_) => const UserHomeScreen()),
            (_) => false);
      }
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack("Connection error. Is the server running?");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ZynkColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _emailC.dispose();
    _passC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(children: [
        // ── Accent blob top-right ──────────────────────────
        Positioned(
          top: -60,
          right: -60,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ZynkColors.primary.withOpacity(0.08),
            ),
          ),
        ),

        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // ── Back ──────────────────────────────────
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: dark
                            ? ZynkColors.darkSurface2
                            : ZynkColors.lightSurf2,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: dark
                                ? ZynkColors.darkBorder
                                : ZynkColors.lightBorder),
                      ),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16,
                          color: dark
                              ? ZynkColors.darkText
                              : ZynkColors.lightText),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── Heading ───────────────────────────────
                  ShaderMask(
                    shaderCallback: (b) =>
                        ZynkGradients.brand.createShader(b),
                    child: const Text(
                      'Welcome\nback.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.5,
                        height: 1.05,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Sign in to your student account',
                    style: TextStyle(
                      color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // ── Fields ────────────────────────────────
                  TextFormField(
                    controller: _emailC,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Enter your email' : null,
                  ),

                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _passC,
                    obscureText: _hidePass,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(_hidePass
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded),
                        onPressed: () =>
                            setState(() => _hidePass = !_hidePass),
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.length < 6 ? 'Min 6 characters' : null,
                  ),

                  const SizedBox(height: 28),

                  ZynkButton(
                    label: 'Sign In',
                    icon: Icons.login_rounded,
                    onTap: _login,
                    isLoading: _loading,
                  ),

                  const SizedBox(height: 24),

                  // ── Signup link ───────────────────────────
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SignUpScreen()),
                      ),
                      child: RichText(
                        text: TextSpan(
                          text: "Don't have an account? ",
                          style: TextStyle(
                            color: dark
                                ? ZynkColors.darkMuted
                                : ZynkColors.lightMuted,
                            fontSize: 14,
                          ),
                          children: const [
                            TextSpan(
                              text: 'Sign up →',
                              style: TextStyle(
                                color: ZynkColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}