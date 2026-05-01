// lib/features/auth/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/admin/screens/admin_home_screen.dart';
import 'package:zynkup/features/auth/screens/login_choice_screen.dart';
import 'package:zynkup/features/user/screens/user_home_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Widget? _destination;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    await ApiService.loadToken();

    Widget next;

    if (!ApiService.hasToken) {
      next = const LoginChoiceScreen();
    } else {
      // Wait for actual user data so role is correct before routing
      final user = await ApiService.getCurrentUser();

      if (user == null) {
        // Token expired or invalid
        await ApiService.logout();
        next = const LoginChoiceScreen();
      } else if (user["role"] == "admin") {
        next = const AdminHomeScreen();
      } else {
        next = const UserHomeScreen();
      }
    }

    if (mounted) setState(() => _destination = next);
  }

  @override
  Widget build(BuildContext context) {
    if (_destination == null) {
      // Branded splash while checking session
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: ZynkGradients.brand),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded, size: 64, color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'ZYNKUP',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                SizedBox(height: 32),
                CircularProgressIndicator(color: Colors.white),
              ],
            ),
          ),
        ),
      );
    }

    return _destination!;
  }
}