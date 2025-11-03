import 'package:flutter/material.dart';

class EventDetailsScreen extends StatelessWidget {
  final String eventId;
  final Map<String, dynamic> eventData;
  const EventDetailsScreen({super.key, required this.eventId, required this.eventData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(eventData['title'] ?? 'Event Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(eventData['title'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(eventData['dateText'] ?? '', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            Text('Venue: ${eventData['venue'] ?? 'TBA'}'),
            const SizedBox(height: 12),
            Text(eventData['description'] ?? 'No description provided.'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // placeholder for register
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Register feature coming soon')));
              },
              child: const Text('Register for event'),
            )
          ],
        ),
      ),
    );
  }
}
