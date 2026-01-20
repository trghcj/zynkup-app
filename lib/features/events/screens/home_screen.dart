import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zynkup/features/auth/screens/login_choice_screen.dart';
import 'package:zynkup/features/events/screens/create_event_screen.dart';
import 'package:zynkup/features/widgets/event_list_widget.dart';
import 'package:zynkup/features/user/services/user_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();

    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginChoiceScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return FutureBuilder<bool>(
      future: UserService().isAdmin(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final isAdmin = snapshot.data ?? false;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              isAdmin ? 'Admin Dashboard' : 'Zynkup Events',
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
                onPressed: () => _logout(context),
              ),
            ],
          ),

          body: const EventListWidget(),

          floatingActionButton: isAdmin
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
      },
    );
  }
}
