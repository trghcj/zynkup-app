import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zynkup/features/user/models/user_model.dart';  // ADD THIS LINE

class UserService {
  final CollectionReference _users =
      FirebaseFirestore.instance.collection('users');

  // Create user profile after sign-up
  Future<void> createUserProfile(AppUser user) async {
    await _users.doc(user.uid).set({
      'email': user.email,
      'name': user.name,
      'role': user.role.name,
      'registeredEvents': user.registeredEvents,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Get current user profile (stream for real-time updates)
  Stream<AppUser?> getUserStream(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (doc.exists) {
        return AppUser.fromFirestore(doc);
      }
      return null;
    });
  }

  // Get user once (for non-reactive use)
  Future<AppUser?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (doc.exists) {
      return AppUser.fromFirestore(doc);
    }
    return null;
  }

  // Update user role (admin only)
  Future<void> updateUserRole(String uid, UserRole newRole) async {
    await _users.doc(uid).update({'role': newRole.name});
  }

  // Register user for an event
  Future<void> registerForEvent(String userId, String eventId) async {
    await _users.doc(userId).update({
      'registeredEvents': FieldValue.arrayUnion([eventId])
    });
  }

  // Unregister from event
  Future<void> unregisterFromEvent(String userId, String eventId) async {
    await _users.doc(userId).update({
      'registeredEvents': FieldValue.arrayRemove([eventId])
    });
  }
}