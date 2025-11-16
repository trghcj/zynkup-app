import 'package:cloud_firestore/cloud_firestore.dart';

enum EventCategory {
  tech,
  cultural,
  sports,
  workshop,
}

class Event {
  final String id;
  final String title;
  final String description;
  final String venue;
  final DateTime date;
  final EventCategory category;
  final String organizerId;
  final List<String> registeredUsers;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.venue,
    required this.date,
    required this.category,
    required this.organizerId,
    this.registeredUsers = const [],
  });

  // FROM FIRESTORE
  factory Event.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Event(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      venue: data['venue'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      category: EventCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => EventCategory.tech,
      ),
      organizerId: data['organizerId'] ?? '',
      registeredUsers: List<String>.from(data['registeredUsers'] ?? []),
    );
  }

  // TO FIRESTORE
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'venue': venue,
      'date': Timestamp.fromDate(date),
      'category': category.name,
      'organizerId': organizerId,
      'registeredUsers': registeredUsers,
    };
  }

  // ADD THIS: copyWith METHOD
  Event copyWith({
    String? id,
    String? title,
    String? description,
    String? venue,
    DateTime? date,
    EventCategory? category,
    String? organizerId,
    List<String>? registeredUsers,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      venue: venue ?? this.venue,
      date: date ?? this.date,
      category: category ?? this.category,
      organizerId: organizerId ?? this.organizerId,
      registeredUsers: registeredUsers ?? this.registeredUsers,
    );
  }
}