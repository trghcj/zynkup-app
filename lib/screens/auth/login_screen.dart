import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    return Scaffold(
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.login),
          label: const Text("Login with Google"),
          onPressed: () async {
            await authService.signInWithGoogle();
          },
        ),
      ),
    );
  }
}
