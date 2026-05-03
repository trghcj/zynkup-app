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

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  final _confirmC = TextEditingController();
  bool _loading = false;
  bool _hidePass = true;
  bool _hideConfirm = true;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));
    _animController.forward();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
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
    _animController.dispose();
    _emailC.dispose();
    _passC.dispose();
    _confirmC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 700;

    return Scaffold(
      body: isWide ? _buildWideLayout() : _buildNarrowLayout(),
    );
  }

  // ── Wide layout (tablet/web) — split panel ─────────────────────────────────
  Widget _buildWideLayout() {
    return Row(
      children: [
        // Left brand panel
        Expanded(
          child: Container(
            decoration: const BoxDecoration(gradient: ZynkGradients.brand),
            child: _buildBrandPanel(),
          ),
        ),
        // Right form panel
        Expanded(
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 48, vertical: 40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: _buildFormContent(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Narrow layout (phone) ──────────────────────────────────────────────────
  Widget _buildNarrowLayout() {
    return Stack(
      children: [
        // Brand bg top strip
        Container(
          height: 260,
          decoration: const BoxDecoration(gradient: ZynkGradients.brand),
        ),

        // Decorative grid pattern
        Positioned(
          top: 30,
          right: 16,
          child: Opacity(
            opacity: 0.12,
            child: Icon(Icons.grid_4x4_rounded,
                size: 160, color: Colors.white),
          ),
        ),

        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button + header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Join\nZynkup.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.5,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Create your account in seconds',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // White card for form
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: _buildFormContent(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Left brand panel (wide only) ───────────────────────────────────────────
  Widget _buildBrandPanel() {
    return Stack(
      children: [
        // Grid pattern
        Positioned(
          bottom: -40,
          left: -40,
          child: Opacity(
            opacity: 0.1,
            child: Icon(Icons.grid_4x4_rounded,
                size: 280, color: Colors.white),
          ),
        ),
        Positioned(
          top: 60,
          right: -20,
          child: Opacity(
            opacity: 0.07,
            child:
                Icon(Icons.circle_outlined, size: 180, color: Colors.white),
          ),
        ),

        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo chip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded,
                          color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text('ZYNKUP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          )),
                    ],
                  ),
                ),

                const Spacer(),

                const Text(
                  'Your campus,\nunlocked.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.5,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Discover events, register instantly,\nand never miss what matters.',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.75), fontSize: 15),
                ),

                const SizedBox(height: 40),

                // Stats row
                Row(
                  children: [
                    _statChip('50+', 'Events'),
                    const SizedBox(width: 12),
                    _statChip('1k+', 'Students'),
                    const SizedBox(width: 12),
                    _statChip('20+', 'Clubs'),
                  ],
                ),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statChip(String value, String label) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11)),
          ],
        ),
      );

  // ── Shared form content ────────────────────────────────────────────────────
  Widget _buildFormContent() {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Heading (shown on wide layout only inside the form card)
              Builder(builder: (ctx) {
                final isWide = MediaQuery.of(ctx).size.width > 700;
                if (!isWide) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button for wide layout
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 38,
                        height: 38,
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
                    const SizedBox(height: 32),
                    const Text(
                      'Create account',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sign in to your student account',
                      style: TextStyle(
                          color: dark
                              ? ZynkColors.darkMuted
                              : ZynkColors.lightMuted,
                          fontSize: 14),
                    ),
                    const SizedBox(height: 32),
                  ],
                );
              }),

              // Email
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

              // Password
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
                    v == null || v.length < 8 ? 'Min 8 characters' : null,
              ),

              const SizedBox(height: 14),

              // Confirm password
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

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}