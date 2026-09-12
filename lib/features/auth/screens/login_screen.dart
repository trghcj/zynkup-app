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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = isDark
        ? const Color(0xFF969DA8)
        : const Color(0xFF4B5563);
    final primaryAccent = isDark
        ? const Color(0xFFC7D437)
        : const Color(0xFF65A30D);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                          child: Image.asset('assets/logos/zynkup_logo.jpg', height: 38, width: 38),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'ZynkUp',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // HERO TEXT
                    Text(
                      'Your Campus,\nConnected.',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                        letterSpacing: -1.2,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // DESCRIPTION
                    Text(
                      'Discover events, join communities, find opportunities, and build meaningful campus connections.',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // FEATURE LIST
                    _buildFeatureRow('Campus Events', textPrimary, primaryAccent),
                    const SizedBox(height: 14),
                    _buildFeatureRow('Student Communities', textPrimary, primaryAccent),
                    const SizedBox(height: 14),
                    _buildFeatureRow('Opportunities', textPrimary, primaryAccent),
                    const SizedBox(height: 14),
                    _buildFeatureRow('Networking', textPrimary, primaryAccent),
                    
                    const SizedBox(height: 28),

                    // CTA TRANSITION
                    Row(
                      children: [
                        Container(
                          width: 3,
                          height: 14,
                          decoration: BoxDecoration(
                            color: primaryAccent,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Ready to join your campus?',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // CTA
                    _buildGoogleButton(isDark),
                    
                    const SizedBox(height: 32),

                    // LEGAL LINKS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildFooterLink('Terms', textSecondary),
                        _buildFooterDot(textSecondary),
                        _buildFooterLink('Privacy', textSecondary),
                        _buildFooterDot(textSecondary),
                        _buildFooterLink('Contact', textSecondary),
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

  Widget _buildFeatureRow(String text, Color textPrimary, Color primaryAccent) {
    return Row(
      children: [
        Icon(Icons.check_circle_rounded, color: primaryAccent, size: 20),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            color: textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleButton(bool isDark) {
    final btnBg = isDark ? const Color(0xFFF4F5F7) : Colors.white;
    final btnText = isDark ? const Color(0xFF090B0F) : const Color(0xFF1F2937);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: btnBg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: _googleLogin,
          borderRadius: BorderRadius.circular(14),
          highlightColor: Colors.black.withValues(alpha: 0.05),
          splashColor: Colors.black.withValues(alpha: 0.05),
          child: Container(
            height: 54,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: isDark
                  ? null
                  : Border.all(color: const Color(0xFFD1D5DB), width: 1.2),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _loading
                ? Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(btnText),
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
                            Icon(Icons.g_mobiledata, color: btnText, size: 32),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Continue with Google',
                        style: TextStyle(
                          color: btnText,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterLink(String text, Color textSecondary) {
    return Text(
      text,
      style: TextStyle(
        color: textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget _buildFooterDot(Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text('•', style: TextStyle(color: textSecondary, fontSize: 14)),
    );
  }
}