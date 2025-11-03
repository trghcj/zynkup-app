import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { participant, organizer, admin }

class AppUser {
  final String uid;
  final String email;
  final String? name;
  final UserRole role;
  final List<String> registeredEvents;
  final DateTime? createdAt;

  AppUser({
    required this.uid,
    required this.email,
    this.name,
    this.role = UserRole.participant,
    this.registeredEvents = const [],
    this.createdAt,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      email: data['email'] ?? '',
      name: data['name'],
      role: UserRole.values.firstWhere(
        (e) => e.toString() == 'UserRole.${data['role']}',
        orElse: () => UserRole.participant,
      ),
      registeredEvents: List<String>.from(data['registeredEvents'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'name': name,
      'role': role.name,
      'registeredEvents': registeredEvents,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }
}