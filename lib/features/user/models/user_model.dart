// lib/features/user/models/user_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { participant, organizer, admin }

class AppUser {
  final String uid;
  final String email;
  final String? name;
  final UserRole role;
  final List<String> registeredEvents;
  final DateTime? createdAt;
  final bool isProfileComplete; // NEW FIELD

  AppUser({
    required this.uid,
    required this.email,
    this.name,
    this.role = UserRole.participant,
    this.registeredEvents = const [],
    this.createdAt,
    this.isProfileComplete = false, // DEFAULT: false
  });

  // FROM FIRESTORE
  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return AppUser(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      name: data['name'] as String?,
      role: _parseRole(data['role'] as String?),
      registeredEvents: List<String>.from(data['registeredEvents'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      isProfileComplete: data['isProfileComplete'] as bool? ?? false,
    );
  }

  // TO FIRESTORE
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'name': name,
      'role': role.name,
      'registeredEvents': registeredEvents,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'isProfileComplete': isProfileComplete,
    };
  }

  // SAFE ROLE PARSING
  static UserRole _parseRole(String? roleStr) {
    if (roleStr == null) return UserRole.participant;
    return UserRole.values.firstWhere(
      (e) => e.name == roleStr,
      orElse: () => UserRole.participant,
    );
  }

  // COPY WITH METHOD (SUPER USEFUL)
  AppUser copyWith({
    String? name,
    UserRole? role,
    List<String>? registeredEvents,
    bool? isProfileComplete,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      name: name ?? this.name,
      role: role ?? this.role,
      registeredEvents: registeredEvents ?? this.registeredEvents,
      createdAt: createdAt,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
    );
  }
}