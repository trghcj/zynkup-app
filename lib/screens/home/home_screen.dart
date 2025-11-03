import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import 'event_details_screen.dart';
import '../../widgets/event_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final eventsRef = FirebaseFirestore.instance.collection('events').orderBy('date', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ZynkUp'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.signOut();
              if (!context.mounted) return;
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: eventsRef.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No events yet. Admin can add events in Firestore.'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final id = docs[index].id;
              return EventCard(
                title: data['title'] ?? 'Untitled',
                subtitle: data['venue'] ?? '',
                dateText: data['dateText'] ?? '',
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailsScreen(eventId: id, eventData: data)));
                },
              );
            },
          );
        },
      ),
    );
  }
}
