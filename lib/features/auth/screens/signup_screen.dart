// lib/features/auth/screens/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/user/screens/profile_setup_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  final _confirmC = TextEditingController();
  bool _loading = false;
  bool _hidePass = true;
  bool _hideConfirm = true;

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ApiService.signUp(_emailC.text.trim(), _passC.text.trim());
      if (!mounted) return;
      _snack("Account created! Let's set up your profile 🎉",
          ZynkColors.success);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
        (_) => false,
      );
    } on ApiException catch (e) {
      _snack(e.message, ZynkColors.error);
    } catch (_) {
      _snack("Signup failed. Please try again.", ZynkColors.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _emailC.dispose();
    _passC.dispose();
    _confirmC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(children: [
        Positioned(
          bottom: -80,
          right: -80,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ZynkColors.accent.withOpacity(0.07),
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

                  ShaderMask(
                    shaderCallback: (b) =>
                        ZynkGradients.brand.createShader(b),
                    child: const Text(
                      'Join\nZynkup.',
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
                    'Create your account in seconds',
                    style: TextStyle(
                      color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 36),

                  TextFormField(
                    controller: _emailC,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter your email';
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    },
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
                    validator: (v) => v == null || v.length < 8
                        ? 'Min 8 characters'
                        : null,
                  ),

                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _confirmC,
                    obscureText: _hideConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm password',
                      prefixIcon: const Icon(Icons.lock_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(_hideConfirm
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded),
                        onPressed: () =>
                            setState(() => _hideConfirm = !_hideConfirm),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Confirm password';
                      if (v != _passC.text) return 'Passwords do not match';
                      return null;
                    },
                  ),

                  const SizedBox(height: 28),

                  ZynkButton(
                    label: 'Create Account',
                    icon: Icons.person_add_rounded,
                    onTap: _signUp,
                    isLoading: _loading,
                  ),

                  const SizedBox(height: 24),

                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: RichText(
                        text: TextSpan(
                          text: 'Already have an account? ',
                          style: TextStyle(
                            color: dark
                                ? ZynkColors.darkMuted
                                : ZynkColors.lightMuted,
                            fontSize: 14,
                          ),
                          children: const [
                            TextSpan(
                              text: 'Sign in →',
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