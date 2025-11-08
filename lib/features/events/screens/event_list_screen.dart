import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zynkup/core/utils/string_extensions.dart';
import 'package:zynkup/features/events/models/event_model.dart';
import 'package:zynkup/features/events/services/event_service.dart';
import 'package:zynkup/features/events/screens/event_details_screen.dart';

class EventListScreen extends StatelessWidget {
  final EventCategory? category;
  const EventListScreen({super.key, this.category});

  @override
  Widget build(BuildContext context) {
    final EventService eventService = EventService();
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<List<Event>>(
      stream: category == null
          ? eventService.getEvents()
          : eventService.getEventsByCategory(category!),
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.deepPurple),
                SizedBox(height: 16),
                Text('Loading events...', style: TextStyle(color: Colors.deepPurple)),
              ],
            ),
          );
        }

        // Error
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}', textAlign: TextAlign.center),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => eventService.getEvents(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        // Empty
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async => await Future.delayed(const Duration(seconds: 1)),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        category == null
                            ? 'No events yet'
                            : 'No ${category!.name.capitalize()} events',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text('Pull to refresh', style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        final events = snapshot.data!;

        return RefreshIndicator(
          onRefresh: () async => await Future.delayed(const Duration(milliseconds: 800)),
          color: Colors.deepPurple,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              final isOrganizer = currentUserId == event.organizerId;

              return Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    event.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 14, color: Colors.deepPurple),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMM dd, yyyy • hh:mm a').format(event.date),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: Colors.red),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event.venue,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Category Chip
                      Chip(
                        label: Text(
                          event.category.name.capitalize(),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        backgroundColor: _getCategoryColor(event.category).withOpacity(0.2),
                        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      // DELETE BUTTON (Organizer Only)
                      if (isOrganizer)
                        IconButton(
                          icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 22),
                          tooltip: 'Delete Event',
                          onPressed: () => _showDeleteDialog(context, eventService, event),
                        ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => EventDetailsScreen(event: event)),
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

  // DELETE CONFIRMATION DIALOG
  void _showDeleteDialog(BuildContext context, EventService service, Event event) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Event?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${event.title}"?\n\nThis action cannot be undone.',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await service.deleteEvent(event.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Event deleted successfully!'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Category color mapping
  Color _getCategoryColor(EventCategory category) {
    switch (category) {
      case EventCategory.tech:
        return Colors.blue;
      case EventCategory.cultural:
        return Colors.purple;
      case EventCategory.sports:
        return Colors.green;
      case EventCategory.workshop:
        return Colors.orange;
    }
  }
}