import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/home/screens/home_screen.dart';

class UserLoginScreen extends StatefulWidget {
  const UserLoginScreen({super.key});

  @override
  State<UserLoginScreen> createState() => _UserLoginScreenState();
}

class _UserLoginScreenState extends State<UserLoginScreen> {
  bool _loading = false;

  Future<void> _googleLogin() async {
    setState(() => _loading = true);
    try {
      final account = await GoogleSignIn(scopes: ['email', 'profile']).signIn();
      if (account == null) return;
      final auth = await account.authentication;
      final token = auth.idToken;
      if (token == null || token.isEmpty) {
        throw const ApiException('Google did not return an ID token.');
      }
      await ApiService.googleLogin(token);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } on ApiException catch (error) {
      _show(error.message);
    } catch (error) {
      _show('Google sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: ZynkColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZynkColors.darkBg,
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(
                Icons.bolt_rounded,
                color: ZynkColors.primary,
                size: 64,
              ),
              const SizedBox(height: 18),
              const Text(
                'Sign in to unlock Zynkup',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ZynkColors.darkText,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Create events, register instantly, get QR passes, and track your campus activity.',
                textAlign: TextAlign.center,
                style: TextStyle(color: ZynkColors.darkMuted, height: 1.5),
              ),
              const Spacer(),
              ZynkButton(
                label: 'Sign in with Google',
                icon: Icons.login_rounded,
                isLoading: _loading,
                onTap: _googleLogin,
              ),
              const SizedBox(height: 12),
              ZynkButton(
                label: 'Continue as Guest',
                outlined: true,
                icon: Icons.visibility_rounded,
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
