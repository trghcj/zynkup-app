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

class _UserLoginScreenState extends State<UserLoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey  = GlobalKey<FormState>();
  final _emailC   = TextEditingController();
  final _passC    = TextEditingController();
  bool _loading   = false;
  bool _hidePass  = true;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailC.dispose();
    _passC.dispose();
    super.dispose();
  }

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

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: ZynkColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 700;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0A07),
      body: isWide ? _wideLayout() : _narrowLayout(),
    );
  }

  // ── Wide layout (tablet / desktop) ───────────────────────────────────────
  Widget _wideLayout() {
    return Row(children: [
      // Left panel — brand visual
      Expanded(flex: 5, child: _BrandPanel()),
      // Right panel — form
      Expanded(flex: 5, child: _formPanel()),
    ]);
  }

  // ── Narrow layout (phone) ─────────────────────────────────────────────────
  Widget _narrowLayout() {
    return Stack(children: [
      // Background gradient
      Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.8, -0.8),
            radius: 1.2,
            colors: [Color(0xFF3D1A08), Color(0xFF0F0A07)],
          ),
        ),
      ),
      SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: _formContent(narrow: true),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _formPanel() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: dark ? const Color(0xFF120D09) : const Color(0xFF1A1108),
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
              child: _formContent(narrow: false),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formContent({required bool narrow}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (narrow) ...[
              const SizedBox(height: 24),
              // Small logo row on mobile
              Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 15, color: Colors.white54),
                  ),
                ),
              ]),
              const SizedBox(height: 40),
            ],

            // ── Heading ──────────────────────────────────────
            ShaderMask(
              shaderCallback: (b) => ZynkGradients.brand.createShader(b),
              child: const Text(
                'Welcome\nback.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2,
                  height: 1.0,
                ),
              ),
            ),

            const SizedBox(height: 10),

            Text('Sign in to your student account',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 14)),

            const SizedBox(height: 40),

            // ── Email ─────────────────────────────────────────
            _AuthField(
              controller: _emailC,
              label: 'Email address',
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Enter your email' : null,
            ),

            const SizedBox(height: 12),

            // ── Password ──────────────────────────────────────
            _AuthField(
              controller: _passC,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              obscure: _hidePass,
              toggleObscure: () =>
                  setState(() => _hidePass = !_hidePass),
              validator: (v) =>
                  v == null || v.length < 6 ? 'Min 6 characters' : null,
            ),

            const SizedBox(height: 28),

            // ── Sign in button ────────────────────────────────
            _AuthButton(
              label: 'Sign In',
              icon: Icons.login_rounded,
              onTap: _login,
              isLoading: _loading,
            ),

            const SizedBox(height: 28),

            // ── Divider ───────────────────────────────────────
            Row(children: [
              Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('or',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 12)),
              ),
              Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
            ]),

            const SizedBox(height: 24),

            // ── Sign up link ──────────────────────────────────
            GestureDetector(
              onTap: () => Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const SignUpScreen())),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  text: "Don't have an account?  ",
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 14),
                  children: const [
                    TextSpan(
                      text: 'Sign up →',
                      style: TextStyle(
                          color: ZynkColors.primary,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),

            if (!narrow) ...[
              const SizedBox(height: 40),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.arrow_back_ios_new_rounded,
                      size: 11,
                      color: Colors.white.withValues(alpha: 0.3)),
                  const SizedBox(width: 6),
                  Text('Back',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 13)),
                ]),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Brand panel (left side on wide screens) ───────────────────────────────────

class _BrandPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7A2E06), Color(0xFF3D1408), Color(0xFF1A0A04)],
        ),
      ),
      child: Stack(fit: StackFit.expand, children: [
        // Grid texture overlay
        Opacity(
          opacity: 0.06,
          child: GridPaper(
            color: Colors.white,
            divisions: 1,
            subdivisions: 1,
            interval: 40,
            child: const SizedBox.expand(),
          ),
        ),
        // Radial glow
        Positioned(
          top: -100, left: -100,
          child: Container(
            width: 400, height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                ZynkColors.primary.withValues(alpha: 0.35),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        // Bottom glow
        Positioned(
          bottom: -80, right: -80,
          child: Container(
            width: 300, height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                ZynkColors.primaryDark.withValues(alpha: 0.4),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        // Content
        Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: ZynkColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.bolt_rounded,
                        color: Colors.white, size: 14),
                  ),
                  const SizedBox(width: 8),
                  const Text('ZYNKUP',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 1.5)),
                ]),
              ),

              const Spacer(),

              // Tagline
              Text(
                'Your campus,\nunlocked.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.5,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Discover events, register instantly,\nand never miss what matters.',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 14,
                    height: 1.6),
              ),

              const SizedBox(height: 48),

              // Stats row
              Row(children: [
                _StatChip(label: 'Events', value: '20+'),
                const SizedBox(width: 12),
                _StatChip(label: 'Students', value: '1k+'),
                const SizedBox(width: 12),
                _StatChip(label: 'Clubs', value: '10+'),
              ]),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18)),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11)),
        ]),
      );
}

// ── Shared form field ─────────────────────────────────────────────────────────

class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final VoidCallback? toggleObscure;
  final String? Function(String?)? validator;

  const _AuthField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscure = false,
    this.toggleObscure,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        prefixIcon: Icon(icon,
            color: Colors.white.withValues(alpha: 0.35), size: 20),
        suffixIcon: toggleObscure != null
            ? IconButton(
                icon: Icon(
                    obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: Colors.white.withValues(alpha: 0.35),
                    size: 20),
                onPressed: toggleObscure,
              )
            : null,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: ZynkColors.primary.withValues(alpha: 0.8)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ZynkColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ZynkColors.error),
        ),
      ),
    );
  }
}

// ── Shared auth button ────────────────────────────────────────────────────────

class _AuthButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isLoading;
  final Color? bgColor;

  const _AuthButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isLoading = false,
    // ignore: unused_element_parameter
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor ?? ZynkColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
              ]),
      ),
    );
  }
}