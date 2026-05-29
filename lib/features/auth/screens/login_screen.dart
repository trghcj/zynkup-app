import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  // Web client ID from Firebase console (type 3 - web client)
  static const _webClientId =
      '659234851207-o80f3633j9f09j79d0ml7376o7v4iv58.apps.googleusercontent.com';

  Future<void> _googleLogin() async {
    // Prevent duplicate popup if already loading
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final googleIdToken = await _signInWithGoogle();

      if (googleIdToken == null || googleIdToken.isEmpty) {
        throw const ApiException('Google did not return an ID token.');
      }

      // Send the GOOGLE id token (not Firebase token) to your backend
      await ApiService.googleLogin(googleIdToken);

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } on ApiException catch (error) {
      _show(error.message);
    } catch (error) {
      // Ignore user-cancelled or duplicate popup errors silently
      final msg = error.toString();
      if (msg.contains('cancelled-popup-request') ||
          msg.contains('popup-closed-by-user')) {
        return;
      }
      _show('Google sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Returns the raw Google ID token (not Firebase token).
  /// Backend needs this to verify via Google's tokeninfo endpoint.
  Future<String?> _signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // ── Web: signInWithPopup → extract Google credential's idToken ──────
        final googleProvider = GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile')
          ..setCustomParameters({'prompt': 'select_account'});

        final userCredential =
            await FirebaseAuth.instance.signInWithPopup(googleProvider);

        // OAuthCredential carries the original Google ID token
        final oauthCredential =
            userCredential.credential as OAuthCredential?;
        return oauthCredential?.idToken; // ← Google ID token ✅
      }

      // ── Mobile (Android / iOS) ────────────────────────────────────────────
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        serverClientId: _webClientId,
      );

      await googleSignIn.signOut(); // force account picker

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null; // user cancelled

      final googleAuth = await googleUser.authentication;
      return googleAuth.idToken; // ← Google ID token ✅
    } catch (e) {
      debugPrint('GOOGLE SIGN IN ERROR: $e');
      rethrow;
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

            ],
          ),
        ),
      ),
    );
  }
}