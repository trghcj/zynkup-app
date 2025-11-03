import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zynkup/features/events/models/event_model.dart';
import 'package:zynkup/features/events/services/event_service.dart';
// Import EventDetailScreen when ready

class EventListScreen extends StatelessWidget {
  final EventCategory? category;
  const EventListScreen({super.key, this.category});

  @override
  Widget build(BuildContext context) {
    final EventService eventService = EventService();

    return StreamBuilder<List<Event>>(
      stream: category == null
          ? eventService.getEvents()
          : eventService.getEventsByCategory(category!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No events found'));
        }

        final events = snapshot.data!;

        return RefreshIndicator(
          onRefresh: () async {
            // Refresh logic (Firestore streams auto-update, but can add manual fetch)
          },
          child: ListView.builder(
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: ListTile(
                  title: Text(event.title),
                  subtitle: Text(
                    '${DateFormat('MMM dd, yyyy - hh:mm a').format(event.date)}\n${event.venue}',
                  ),
                  trailing: Chip(label: Text(event.category.toString().split('.').last)),
                  onTap: () {
                    // Navigate to EventDetailScreen(event: event)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Event Details: ${event.title}')),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}