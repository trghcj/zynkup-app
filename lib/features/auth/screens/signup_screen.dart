import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zynkup/features/auth/services/auth_service.dart';
import 'package:zynkup/features/events/screens/home_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;

  // ---------------- EMAIL SIGN UP ----------------
  Future<void> _signUpWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = await _authService.signUp(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (user == null || !mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Sign up failed');
    } catch (_) {
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------- GOOGLE SIGN UP ----------------
  Future<void> _signUpWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final user = await _authService.signInWithGoogle();

      if (user == null || !mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------- ERROR HANDLER ----------------
  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  const Icon(
                    Icons.person_add_alt_1,
                    size: 90,
                    color: Colors.deepPurple,
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'Join Zynkup',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Sign up to explore campus events',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // EMAIL
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDecoration(
                      label: 'Email',
                      icon: Icons.email_outlined,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter email';
                      }
                      if (!RegExp(
                        r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(value)) {
                        return 'Enter valid email';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // PASSWORD
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _hidePassword,
                    decoration: _inputDecoration(
                      label: 'Password',
                      icon: Icons.lock_outline,
                      suffix: IconButton(
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() => _hidePassword = !_hidePassword);
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter password';
                      }
                      if (value.length < 6) {
                        return 'Minimum 6 characters';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // CONFIRM PASSWORD
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _hideConfirmPassword,
                    decoration: _inputDecoration(
                      label: 'Confirm Password',
                      icon: Icons.lock_outline,
                      suffix: IconButton(
                        icon: Icon(
                          _hideConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() => _hideConfirmPassword =
                              !_hideConfirmPassword);
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 28),

                  // EMAIL SIGN UP BUTTON
                  _isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.deepPurple,
                        )
                      : SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _signUpWithEmail,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                  const SizedBox(height: 16),

                  // GOOGLE SIGN UP
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _signUpWithGoogle,
                      icon: Image.asset(
                        'assets/google_logo.png',
                        height: 22,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.g_mobiledata,
                          size: 30,
                          color: Colors.red,
                        ),
                      ),
                      label: const Text(
                        'Sign up with Google',
                        style: TextStyle(fontSize: 15),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // LOGIN LINK
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text.rich(
                      TextSpan(
                        text: 'Already have an account? ',
                        children: [
                          TextSpan(
                            text: 'Login',
                            style: TextStyle(
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
