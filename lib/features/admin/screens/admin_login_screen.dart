import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:zynkup/features/admin/screens/admin_home_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  /// ✅ ALLOWED ADMIN EMAILS
  static const List<String> adminEmails = [
    'admin@zynkup.com',
    'cdc@mait.ac.in',
    'faculty@mait.ac.in',
    'organizer@gmail.com',
    'admin@gmail.com',
    'ms1778937@gmail.com',
    'singhdivyansh.016cseai@gmail.com',
  ];

  // =========================
  // EMAIL + PASSWORD LOGIN
  // =========================
  Future<void> _loginAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim().toLowerCase();

    if (!adminEmails.contains(email)) {
      _showError('You are not authorized as Admin');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;
      _goToAdminHome();
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Login failed');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =========================
  // GOOGLE SIGN-IN LOGIN
  // =========================
  Future<void> _loginAdminWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final email = userCredential.user?.email?.toLowerCase();

      if (email == null || !adminEmails.contains(email)) {
        await FirebaseAuth.instance.signOut();
        await googleSignIn.signOut();
        _showError('You are not authorized as Admin');
        return;
      }

      if (!mounted) return;
      _goToAdminHome();
    } catch (e) {
      _showError('Google sign-in failed');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =========================
  // NAVIGATION
  // =========================
  void _goToAdminHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
      (_) => false,
    );
  }

  // =========================
  // ERROR UI
  // =========================
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
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

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Login'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const Icon(Icons.admin_panel_settings,
                    size: 80, color: Colors.deepPurple),

                const SizedBox(height: 24),

                /// EMAIL
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Admin Email',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Email required' : null,
                ),

                const SizedBox(height: 16),

                /// PASSWORD
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.length < 6 ? 'Min 6 characters' : null,
                ),

                const SizedBox(height: 28),

                /// EMAIL LOGIN
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _loginAdmin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Login as Admin',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),

                const SizedBox(height: 14),

                /// GOOGLE LOGIN
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed:
                        _isLoading ? null : _loginAdminWithGoogle,
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    label: const Text(
                      'Sign in with Google',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
