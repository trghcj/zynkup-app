import 'package:cloud_firestore/cloud_firestore.dart';

enum EventCategory { tech, cultural, sports, workshop }

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

  /// Convert Firestore Document → Event
  factory Event.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    if (data == null) {
      throw Exception('Document data is null');
    }

    // SAFE CATEGORY PARSING
    EventCategory parseCategory(String? value) {
      if (value == null) return EventCategory.tech;
      return EventCategory.values.firstWhere(
        (e) => e.name == value,
        orElse: () => EventCategory.tech,
      );
    }

    return Event(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      venue: data['venue'] as String? ?? '',
      category: parseCategory(data['category'] as String?),
      organizerId: data['organizerId'] as String? ?? '',
      registeredUsers: List<String>.from(data['registeredUsers'] ?? []),
    );
  }

  /// Convert Event → Firestore Map
  Map<String, dynamic> toFirestore() {
    return {
      'id': id, // FIXED: Include ID in Firestore
      'title': title,
      'description': description,
      'date': Timestamp.fromDate(date),
      'venue': venue,
      'category': category.name,
      'organizerId': organizerId,
      'registeredUsers': registeredUsers,
    };
  }

  /// For debugging
  @override
  String toString() {
    return 'Event(id: $id, title: $title, category: $category, date: $date)';
  }

  /// For equality checks (e.g., in lists)
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Event && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}