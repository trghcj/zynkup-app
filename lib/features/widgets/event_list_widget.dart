// lib/features/events/widgets/event_list_widget.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:zynkup/features/events/models/event_model.dart';
import 'package:zynkup/features/events/screens/event_details_screen.dart';
import 'package:zynkup/core/utils/string_extensions.dart';

class EventListWidget extends StatelessWidget {
  const EventListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Something went wrong',
              style: TextStyle(color: Colors.red),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.deepPurple),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text('No events yet', style: TextStyle(fontSize: 18)),
              ],
            ),
          );
        }

        final events = snapshot.data!.docs
            .map((doc) => Event.fromFirestore(doc))
            .toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            final isUpcoming = event.date.isAfter(DateTime.now());

            return Card(
              elevation: 6,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EventDetailsScreen(event: event),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// IMAGE (FIRST IMAGE ONLY)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: event.imageUrls.isNotEmpty
                            ? Image.network(
                                event.imageUrls.first,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _imagePlaceholder(event),
                              )
                            : _imagePlaceholder(event),
                      ),

                      const SizedBox(width: 16),

                      /// DETAILS
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /// CATEGORY
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _categoryColor(event.category)
                                    .withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                event.category.name.capitalize(),
                                style: TextStyle(
                                  color: _categoryColor(event.category),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            /// TITLE
                            Text(
                              event.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 8),

                            /// DATE & TIME
                            Row(
                              children: [
                                const Icon(Icons.calendar_today,
                                    size: 16,
                                    color: Colors.deepPurple),
                                const SizedBox(width: 6),
                                Text(
                                  DateFormat(
                                          'EEE, MMM dd • hh:mm a')
                                      .format(event.date),
                                  style: TextStyle(
                                    color: isUpcoming
                                        ? Colors.green
                                        : Colors.grey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 6),

                            /// VENUE
                            Row(
                              children: [
                                const Icon(Icons.location_on,
                                    size: 16, color: Colors.red),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    event.venue,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      /// STATUS
                      if (!isUpcoming)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'PAST',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ================= HELPERS =================

  Widget _imagePlaceholder(Event event) {
    return Container(
      width: 100,
      height: 100,
      color: _categoryColor(event.category).withOpacity(0.3),
      child: Icon(
        _categoryIcon(event.category),
        size: 40,
        color: _categoryColor(event.category),
      ),
    );
  }

  Color _categoryColor(EventCategory category) {
    switch (category) {
      case EventCategory.tech:
        return Colors.blue;
      case EventCategory.cultural:
        return Colors.purple;
      case EventCategory.sports:
        return Colors.green;
      case EventCategory.workshop:
        return Colors.orange;
      case EventCategory.seminar:
        return Colors.red;
    }
  }

  IconData _categoryIcon(EventCategory category) {
    switch (category) {
      case EventCategory.tech:
        return Icons.code;
      case EventCategory.cultural:
        return Icons.music_note;
      case EventCategory.sports:
        return Icons.sports_soccer;
      case EventCategory.workshop:
        return Icons.build;
      case EventCategory.seminar:
        return Icons.mic;
    }
  }
}
