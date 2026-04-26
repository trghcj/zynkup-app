import 'package:flutter/material.dart';
import 'package:zynkup/core/api/api_service.dart';
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
      // Wait for actual user data before deciding where to go
      final user = await ApiService.getCurrentUser();

      if (user == null) {
        // Token invalid or expired
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
      // Show branded splash while checking session
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple, Colors.purpleAccent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event, size: 80, color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'ZYNKUP',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
