// lib/features/auth/screens/user_login_screen.dart
import 'package:flutter/material.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/user/screens/profile_setup_screen.dart';
import 'package:zynkup/features/user/screens/user_home_screen.dart';

class UserLoginScreen extends StatefulWidget {
  const UserLoginScreen({super.key});

  @override
  State<UserLoginScreen> createState() => _UserLoginScreenState();
}

class _UserLoginScreenState extends State<UserLoginScreen>
    with TickerProviderStateMixin {
  final _emailC    = TextEditingController();
  final _passwordC = TextEditingController();
  bool _obscure    = true;
  bool _loading    = false;
  bool _isSignUp   = false; // toggle between login and signup

  // ── Animation controllers ──────────────────────────────────────────────────
  late AnimationController _heroCtrl;
  late AnimationController _formCtrl;
  late AnimationController _successCtrl;

  late Animation<double> _heroFade;
  late Animation<double> _heroScale;
  late Animation<double> _formFade;
  late Animation<double> _formScale;
  late Animation<Offset>  _formSlide;
  late Animation<double> _btnScale;

  @override
  void initState() {
    super.initState();

    _heroCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _formCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _successCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));

    _heroFade  = CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut);
    _heroScale = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOutBack));

    _formFade  = CurvedAnimation(parent: _formCtrl, curve: Curves.easeOut);
    _formScale = Tween<double>(begin: 0.92, end: 1.0).animate(
        CurvedAnimation(parent: _formCtrl, curve: Curves.easeOutBack));
    _formSlide = Tween<Offset>(
            begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _formCtrl, curve: Curves.easeOut));

    _btnScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _formCtrl,
            curve: const Interval(0.5, 1.0, curve: Curves.easeOutBack)));

    Future.delayed(const Duration(milliseconds: 100),
        () => _heroCtrl.forward());
    Future.delayed(const Duration(milliseconds: 350),
        () => _formCtrl.forward());
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _formCtrl.dispose();
    _successCtrl.dispose();
    _emailC.dispose();
    _passwordC.dispose();
    super.dispose();
  }

  void _toggleMode() {
    _formCtrl.reset();
    setState(() => _isSignUp = !_isSignUp);
    Future.delayed(const Duration(milliseconds: 50),
        () => _formCtrl.forward());
  }

  Future<void> _submit() async {
    final email    = _emailC.text.trim();
    final password = _passwordC.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }

    setState(() => _loading = true);

    try {
      if (_isSignUp) {
        await ApiService.signUp(email, password);
        _showSuccess('Account created! Please log in.');
        setState(() { _isSignUp = false; _loading = false; });
        _toggleMode();
        return;
      }

    
      final _ = await ApiService.login(email, password);
      if (!mounted) return;

      final user = await ApiService.getCurrentUser();
      if (!mounted) return;

      final isProfileComplete = user?['name'] != null &&
          (user!['name'] as String).isNotEmpty;

      if (!isProfileComplete) {
        Navigator.pushAndRemoveUntil(context,
            _fadeRoute(const ProfileSetupScreen()), (_) => false);
      } else {
        Navigator.pushAndRemoveUntil(context,
            _fadeRoute(const UserHomeScreen()), (_) => false);
      }
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Network error. Check your connection.');
    }

    if (mounted) setState(() => _loading = false);
  }

  PageRouteBuilder _fadeRoute(Widget page) => PageRouteBuilder(
        pageBuilder: (_, a, __) => page,
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      );

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.error_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ]),
          backgroundColor: ZynkColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(msg),
          ]),
          backgroundColor: ZynkColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Stack(
        children: [
          // ── Background ──────────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF18120E), Color(0xFF2D1A0E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),

          // ── Decorative blobs ─────────────────────────────
          Positioned(top: -100, right: -100,
            child: Container(width: 300, height: 300,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: ZynkColors.primary.withOpacity(0.07)))),
          Positioned(bottom: -80, left: -80,
            child: Container(width: 240, height: 240,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: ZynkColors.accent.withOpacity(0.05)))),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 48),

                  // ── Hero section ─────────────────────────
                  FadeTransition(
                    opacity: _heroFade,
                    child: ScaleTransition(
                      scale: _heroScale,
                      child: Column(children: [
                        // Logo
                        Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            gradient: ZynkGradients.brand,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(
                                color: ZynkColors.primary.withOpacity(0.4),
                                blurRadius: 24, offset: const Offset(0, 8))],
                          ),
                          child: const Icon(Icons.bolt_rounded,
                              color: Colors.white, size: 38)),

                        const SizedBox(height: 20),

                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _isSignUp ? 'Create Account' : 'Welcome back.',
                            key: ValueKey(_isSignUp),
                            style: const TextStyle(
                              fontSize: 32, fontWeight: FontWeight.w800,
                              color: Colors.white, letterSpacing: -1),
                          ),
                        ),

                        const SizedBox(height: 6),

                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _isSignUp
                                ? 'Join the MAIT event community'
                                : 'Sign in to your student account',
                            key: ValueKey('sub$_isSignUp'),
                            style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.6)),
                          ),
                        ),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // ── Form card ────────────────────────────
                  FadeTransition(
                    opacity: _formFade,
                    child: ScaleTransition(
                      scale: _formScale,
                      child: SlideTransition(
                        position: _formSlide,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E160F),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                                color: ZynkColors.darkBorder),
                            boxShadow: [BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 32, offset: const Offset(0, 12))],
                          ),
                          padding: const EdgeInsets.all(28),
                          child: Column(children: [
                            // Email
                            _AnimatedField(
                              controller: _emailC,
                              label: 'Email address',
                              icon: Icons.alternate_email_rounded,
                              type: TextInputType.emailAddress,
                              delay: 0,
                              parentCtrl: _formCtrl,
                            ),
                            const SizedBox(height: 14),

                            // Password
                            _AnimatedField(
                              controller: _passwordC,
                              label: 'Password',
                              icon: Icons.lock_outline_rounded,
                              obscure: _obscure,
                              delay: 100,
                              parentCtrl: _formCtrl,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: ZynkColors.darkMuted, size: 20),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),

                            const SizedBox(height: 28),

                            // Submit button
                            ScaleTransition(
                              scale: _btnScale,
                              child: _AnimatedButton(
                                label: _isSignUp ? 'Create Account' : 'Sign In',
                                icon: _isSignUp
                                    ? Icons.person_add_rounded
                                    : Icons.login_rounded,
                                isLoading: _loading,
                                onTap: _submit,
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Toggle
                            GestureDetector(
                              onTap: _toggleMode,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                child: RichText(
                                  key: ValueKey(_isSignUp),
                                  text: TextSpan(
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 13),
                                    children: [
                                      TextSpan(
                                          text: _isSignUp
                                              ? 'Already have an account? '
                                              : "Don't have an account? "),
                                      TextSpan(
                                          text: _isSignUp
                                              ? 'Sign in →'
                                              : 'Sign up →',
                                          style: const TextStyle(
                                              color: ZynkColors.primary,
                                              fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ]),
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

// ── Animated input field ──────────────────────────────────────────────────────

class _AnimatedField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final TextInputType? type;
  final Widget? suffix;
  final int delay;
  final AnimationController parentCtrl;

  const _AnimatedField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.parentCtrl,
    required this.delay,
    this.obscure = false,
    this.type,
    this.suffix,
  });

  @override
  State<_AnimatedField> createState() => _AnimatedFieldState();
}

class _AnimatedFieldState extends State<_AnimatedField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focused
              ? ZynkColors.primary
              : ZynkColors.darkBorder,
          width: _focused ? 1.5 : 1,
        ),
        color: _focused
            ? ZynkColors.primary.withOpacity(0.06)
            : ZynkColors.darkSurface2,
        boxShadow: _focused
            ? [BoxShadow(
                color: ZynkColors.primary.withOpacity(0.15),
                blurRadius: 12)]
            : null,
      ),
      child: Focus(
        onFocusChange: (f) => setState(() => _focused = f),
        child: TextField(
          controller: widget.controller,
          obscureText: widget.obscure,
          keyboardType: widget.type,
          style: const TextStyle(color: ZynkColors.darkText, fontSize: 15),
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: TextStyle(
                color: _focused ? ZynkColors.primary : ZynkColors.darkMuted,
                fontSize: 14),
            prefixIcon: Icon(widget.icon,
                color: _focused ? ZynkColors.primary : ZynkColors.darkMuted,
                size: 20),
            suffixIcon: widget.suffix,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
          ),
        ),
      ),
    );
  }
}

// ── Animated submit button ────────────────────────────────────────────────────

class _AnimatedButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onTap;

  const _AnimatedButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onTap,
  });

  @override
  State<_AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<_AnimatedButton> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp:   (_) { setState(() => _pressed = false); widget.onTap(); },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.96 : _hovered ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              gradient: widget.isLoading ? null : LinearGradient(
                colors: [
                  ZynkColors.primaryDark,
                  ZynkColors.primary,
                  _hovered ? ZynkColors.primaryLight : ZynkColors.terra3,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              color: widget.isLoading
                  ? ZynkColors.primary.withOpacity(0.5) : null,
              borderRadius: BorderRadius.circular(14),
              boxShadow: widget.isLoading || _pressed ? null : [
                BoxShadow(
                  color: ZynkColors.primary.withOpacity(_hovered ? 0.5 : 0.3),
                  blurRadius: _hovered ? 20 : 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: widget.isLoading
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(widget.icon, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(widget.label,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                    ]),
            ),
          ),
        ),
      ),
    );
  }
}