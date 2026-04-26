import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:zynkup/features/auth/screens/login_choice_screen.dart';
import 'package:zynkup/features/events/screens/create_event_screen.dart';
import 'package:zynkup/features/widgets/event_list_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isAdmin = false;
  bool _isLoading = true;

  final String baseUrl = "http://127.0.0.1:8000";

  @override
  void initState() {
    super.initState();
    checkUserRole();
  }

  /// 🔥 GET USER ROLE FROM API
  Future<void> checkUserRole() async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/users/me"),
        headers: {
          // later: add JWT token here
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        setState(() {
          _isAdmin = data["role"] == "admin";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  /// 🔐 LOGOUT (temporary)
  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginChoiceScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isAdmin ? 'Admin Dashboard' : 'Zynkup Events',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),

      /// 📋 EVENTS LIST
      body: const EventListWidget(),

      /// ➕ ADMIN ONLY
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              backgroundColor: Colors.deepPurple,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Create Event',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateEventScreen(),
                  ),
                );
              },
            )
          : null,

      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
    );
  }
}