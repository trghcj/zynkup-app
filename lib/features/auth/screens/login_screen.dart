import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/home/screens/home_screen.dart';
import 'package:zynkup/core/widgets/zynk_background.dart';

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

  static const Color _bgColor = Color(0xFF090B0F);
  static const Color _textPrimary = Color(0xFFF4F5F7);
  static const Color _textSecondary = Color(0xFF969DA8);
  static const Color _primaryAccent = Color(0xFFC7D437);
  static const Color _btnBg = Color(0xFFF4F5F7);
  static const Color _btnText = Color(0xFF090B0F);

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
      backgroundColor: _bgColor,
      body: ZynkBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LOGO SECTION
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset('assets/logos/zynkup_logo.jpg', height: 44, width: 44),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'ZynkUp',
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),

                    // HERO TEXT
                    const Text(
                      'Your Campus,\nConnected.',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 54,
                        fontWeight: FontWeight.w700,
                        height: 0.98,
                        letterSpacing: -1.5,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // DESCRIPTION
                    const Text(
                      'Discover events, join communities, find opportunities, and build meaningful campus connections.',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // FEATURE LIST
                    _buildFeatureRow('Campus Events'),
                    const SizedBox(height: 14),
                    _buildFeatureRow('Student Communities'),
                    const SizedBox(height: 14),
                    _buildFeatureRow('Opportunities'),
                    const SizedBox(height: 14),
                    _buildFeatureRow('Networking'),
                    
                    const SizedBox(height: 44),

                    // CTA
                    _buildGoogleButton(),
                    
                    const SizedBox(height: 32),

                    // LEGAL LINKS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildFooterLink('Terms'),
                        _buildFooterDot(),
                        _buildFooterLink('Privacy'),
                        _buildFooterDot(),
                        _buildFooterLink('Contact'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String text) {
    return Row(
      children: [
        const Icon(Icons.check_circle_rounded, color: _primaryAccent, size: 20),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _googleLogin,
        child: Container(
          height: 56,
          width: double.infinity,
          decoration: BoxDecoration(
            color: _btnBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: _loading
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(_btnText),
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/google_logo.png',
                      height: 24,
                      width: 24,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.g_mobiledata, color: _btnText, size: 32),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Continue with Google',
                      style: TextStyle(
                        color: _btnText,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildFooterLink(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget _buildFooterDot() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 10),
      child: Text('•', style: TextStyle(color: _textSecondary, fontSize: 14)),
    );
  }
}