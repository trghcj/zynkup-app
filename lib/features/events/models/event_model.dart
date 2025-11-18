// lib/features/events/models/event_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum EventCategory {
  tech,
  cultural,
  sports,
  workshop, seminar,
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
  final String? imageUrl;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.venue,
    required this.date,
    required this.category,
    required this.organizerId,
    this.registeredUsers = const [],
    this.imageUrl,
  });

  factory Event.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Event(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      venue: data['venue'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      category: _parseCategory(data['category'] ?? 'tech'),
      organizerId: data['organizerId'] ?? '',
      registeredUsers: List<String>.from(data['registeredUsers'] ?? []),
      imageUrl: data['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'venue': venue,
      'date': Timestamp.fromDate(date),
      'category': category.name,
      'organizerId': organizerId,
      'registeredUsers': registeredUsers,
      if (imageUrl != null) 'imageUrl': imageUrl,
    };
  }

  Event copyWith({
    String? id,
    String? title,
    String? description,
    String? venue,
    DateTime? date,
    EventCategory? category,
    String? organizerId,
    List<String>? registeredUsers,
    String? imageUrl,
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
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  static EventCategory _parseCategory(String value) {
    return EventCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => EventCategory.tech,
    );
  }
}