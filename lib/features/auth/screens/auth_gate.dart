import 'package:flutter/material.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/features/auth/screens/guest_home_screen.dart';
import 'package:zynkup/features/home/screens/home_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  bool _signedIn = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await ApiService.loadToken();
    final signedIn =
        ApiService.hasToken && await ApiService.getCurrentUser() != null;
    if (!mounted) return;
    setState(() {
      _signedIn = signedIn;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _signedIn ? const HomeScreen() : const GuestHomeScreen();
  }
}
