// lib/features/events/screens/home_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zynkup/features/events/screens/create_event_screen.dart';
import 'package:zynkup/features/widgets/event_list_widget.dart'; // your event list

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // ADD YOUR ADMIN EMAILS HERE (same as main.dart)
  static const List<String> adminEmails = [
    'admin@zynkup.com',
    'cdc@mait.ac.in',
    'faculty@mait.ac.in',
    'organizer@gmail.com',
    'admin@gmail.com', // YOUR TEST EMAIL
  ];

  bool get isAdmin {
    final email = FirebaseAuth.instance.currentUser?.email?.toLowerCase();
    return email != null && adminEmails.contains(email);
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = this.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isAdmin ? 'Admin Panel' : 'Zynkup Events',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => FirebaseAuth.instance.signOut(),
              tooltip: 'Logout',
            ),
        ],
      ),

      body: const EventListWidget(), // YOUR EVENT LIST (same for all)

      // ONLY ADMIN SEES THIS BUTTON
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateEventScreen()),
                );
              },
              backgroundColor: Colors.deepPurple,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Create Event',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}