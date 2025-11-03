import 'package:cloud_firestore/cloud_firestore.dart';

enum EventCategory { tech, cultural, sports, workshop }  // Add more as needed

class Event {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final String venue;
  final EventCategory category;
  final String organizerId;
  final List<String> registeredUsers;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.venue,
    required this.category,
    required this.organizerId,
    this.registeredUsers = const [],
  });

  factory Event.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Event(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      venue: data['venue'] ?? '',
      category: EventCategory.values.firstWhere(
        (e) => e.toString() == 'EventCategory.${data['category']}',
        orElse: () => EventCategory.tech,
      ),
      organizerId: data['organizerId'] ?? '',
      registeredUsers: List<String>.from(data['registeredUsers'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'date': Timestamp.fromDate(date),
      'venue': venue,
      'category': category.toString().split('.').last,
      'organizerId': organizerId,
      'registeredUsers': registeredUsers,
    };
  }
}