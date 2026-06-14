import 'dart:ui';
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

  // --- LOCAL COLORS FOR REDESIGN ---
  static const Color _bgColor = Color(0xFF0D1117);
  static const Color _cardColor = Color(0xFF161B22);
  static const Color _textSecondary = Color(0xFF9CA3AF);

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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 800;

          if (isDesktop) {
            return Row(
              children: [
                Expanded(child: _buildLeftPane()),
                Expanded(child: _buildRightPane()),
              ],
            );
          } else {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      _buildLeftPane(isMobile: true),
                      Expanded(child: _buildRightPane(isMobile: true)),
                    ],
                  ),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildLeftPane({bool isMobile = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 32 : 64,
        vertical: 48,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset('assets/logos/icon.jpg', height: 40, width: 40),
              ),
              const SizedBox(width: 12),
              const Text(
                'ZynkUp',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 40 : 80),
          Text(
            'Your Campus,\nConnected.',
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 48 : 64,
              fontWeight: FontWeight.w900,
              height: 1.1,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Discover events, join communities, find opportunities,\nand build meaningful campus connections.',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 18,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 48),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildFeatureChip('🎉', 'Campus Events'),
              _buildFeatureChip('👥', 'Student Communities'),
              _buildFeatureChip('💼', 'Opportunities'),
              _buildFeatureChip('🤝', 'Networking'),
            ],
          ),
          if (!isMobile) ...[
            const Spacer(),
            const Text(
              '👨‍🎓   👩‍🎓\n   🎉\n📚       💼',
              style: TextStyle(fontSize: 48, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeatureChip(String emoji, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightPane({bool isMobile = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 64,
        vertical: 48,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.02),
            Colors.black.withValues(alpha: 0.2),
          ],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Glassmorphism Card
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: _cardColor.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Get Started',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Join thousands of students across campuses.',
                          style: TextStyle(color: _textSecondary, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                        _buildGoogleButton(),
                        const SizedBox(height: 40),
                        _buildBenefitRow('✔', 'Discover Events'),
                        const SizedBox(height: 16),
                        _buildBenefitRow('✔', 'Join Student Communities'),
                        const SizedBox(height: 16),
                        _buildBenefitRow('✔', 'Build Professional Connections'),
                        const SizedBox(height: 16),
                        _buildBenefitRow('✔', 'Access Campus Opportunities'),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // Footer
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
              const SizedBox(height: 16),
              const Text(
                '© 2026 Zynkup',
                style: TextStyle(color: _textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitRow(String icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: ZynkColors.primary.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Text(
            icon,
            style: const TextStyle(
              color: ZynkColors.primary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
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
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _loading
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
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
                          const Icon(Icons.g_mobiledata, color: Colors.black, size: 32),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Continue with Google',
                      style: TextStyle(
                        color: Colors.black87,
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
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildFooterDot() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: Text('•', style: TextStyle(color: _textSecondary)),
    );
  }
}