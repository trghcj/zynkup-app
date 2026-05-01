// lib/features/auth/screens/user_login_screen.dart

import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
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

  final _emailC = TextEditingController();
  final _passwordC = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  bool _isSignUp = false;

  late AnimationController _heroCtrl;
  late AnimationController _formCtrl;
  late ConfettiController _confettiCtrl;

  late Animation<double> _heroFade;
  late Animation<double> _heroScale;

  late Animation<double> _formFade;
  late Animation<double> _formScale;

  @override
  void initState() {
    super.initState();

    _heroCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _formCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _confettiCtrl = ConfettiController(
        duration: const Duration(milliseconds: 800));

    _heroFade = CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut);
    _heroScale = Tween(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOutBack));

    _formFade = CurvedAnimation(parent: _formCtrl, curve: Curves.easeOut);
    _formScale = Tween(begin: 0.92, end: 1.0).animate(
        CurvedAnimation(parent: _formCtrl, curve: Curves.easeOutBack));

    Future.delayed(const Duration(milliseconds: 100),
        () => _heroCtrl.forward());
    Future.delayed(const Duration(milliseconds: 300),
        () => _formCtrl.forward());
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _formCtrl.dispose();
    _confettiCtrl.dispose();
    _emailC.dispose();
    _passwordC.dispose();
    super.dispose();
  }

  void _toggleMode() {
    _formCtrl.reset();
    setState(() => _isSignUp = !_isSignUp);
    Future.delayed(const Duration(milliseconds: 100),
        () => _formCtrl.forward());
  }

  Future<void> _submit() async {
    final email = _emailC.text.trim();
    final password = _passwordC.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError("Fill all fields");
      return;
    }

    setState(() => _loading = true);

    try {
      if (_isSignUp) {
        await ApiService.signUp(email, password);
        _showSuccess("Account created!");
        _toggleMode();
        setState(() => _loading = false);
        return;
      }

      await ApiService.login(email, password);

      _confettiCtrl.play(); // 🎉 SUCCESS

      await Future.delayed(const Duration(milliseconds: 500));

      final user = await ApiService.getCurrentUser();

      final isProfileComplete =
          user?['name'] != null && user!['name'].toString().isNotEmpty;

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => isProfileComplete
              ? const UserHomeScreen()
              : const ProfileSetupScreen(),
        ),
        (_) => false,
      );
    } catch (e) {
      _showError("Login failed");
    }

    if (mounted) setState(() => _loading = false);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: ZynkColors.error),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: ZynkColors.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A120B), Color(0xFF2D1A0E)],
              ),
            ),
          ),

          // 🎉 Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiCtrl,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.orange,
                Colors.white,
                Colors.deepOrange
              ],
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  // Logo
                  FadeTransition(
                    opacity: _heroFade,
                    child: ScaleTransition(
                      scale: _heroScale,
                      child: Column(
                        children: const [
                          Icon(Icons.bolt, size: 50, color: Colors.orange),
                          SizedBox(height: 10),
                          Text("Zynkup",
                              style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Form
                  FadeTransition(
                    opacity: _formFade,
                    child: ScaleTransition(
                      scale: _formScale,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E160F),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            _StaggerField(
                              controller: _emailC,
                              label: "Email",
                              delay: 0,
                            ),
                            const SizedBox(height: 12),
                            _StaggerField(
                              controller: _passwordC,
                              label: "Password",
                              obscure: _obscure,
                              delay: 150,
                            ),

                            const SizedBox(height: 20),

                            ElevatedButton(
                              onPressed: _loading ? null : _submit,
                              child: _loading
                                  ? const CircularProgressIndicator()
                                  : Text(_isSignUp
                                      ? "Create Account"
                                      : "Login"),
                            ),

                            TextButton(
                              onPressed: _toggleMode,
                              child: Text(_isSignUp
                                  ? "Already have account? Login"
                                  : "Create account"),
                            )
                          ],
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _StaggerField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final int delay;

  const _StaggerField({
    required this.controller,
    required this.label,
    required this.delay,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    final animation = CurvedAnimation(
      parent: ModalRoute.of(context)!.animation!,
      curve: Interval(delay / 600, 1.0, curve: Curves.easeOut),
    );

    return FadeTransition(
      opacity: animation,
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}