// lib/features/user/screens/user_login_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zynkup/features/auth/services/auth_service.dart';
import 'package:zynkup/features/auth/screens/signup_screen.dart';

class UserLoginScreen extends StatefulWidget {
  const UserLoginScreen({super.key});

  @override
  State<UserLoginScreen> createState() => _UserLoginScreenState();
}

class _UserLoginScreenState extends State<UserLoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // ================= EMAIL LOGIN =================
  Future<void> _loginWithEmailPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _authService.signInWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      // 🚫 DO NOT NAVIGATE HERE
      // ✅ AuthGate will decide next screen

    } on FirebaseAuthException catch (e) {
      _showSnackBar(_firebaseErrorMessage(e), Colors.redAccent);
    } catch (_) {
      _showSnackBar('Something went wrong. Try again.', Colors.orange);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ================= GOOGLE LOGIN =================
  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      await _authService.signInWithGoogle();
      // AuthGate handles navigation
    } catch (_) {
      _showSnackBar('Google Sign-In failed', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _firebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found for this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This account is disabled';
      case 'too-many-requests':
        return 'Too many attempts. Try later';
      default:
        return e.message ?? 'Login failed';
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Icon(Icons.event, size: 90, color: Colors.deepPurple),
                  const SizedBox(height: 16),

                  const Text(
                    'User Login',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 30),

                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (v) =>
                        v!.isEmpty ? 'Enter email' : null,
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) =>
                        v!.length < 6 ? 'Min 6 characters' : null,
                  ),

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed:
                          _isLoading ? null : _loginWithEmailPassword,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('LOGIN'),
                    ),
                  ),

                  const SizedBox(height: 16),

                  OutlinedButton(
                    onPressed: _isLoading ? null : _loginWithGoogle,
                    child: const Text('Continue with Google'),
                  ),

                  const SizedBox(height: 20),

                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SignUpScreen(),
                        ),
                      );
                    },
                    child: const Text('Create New Account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
