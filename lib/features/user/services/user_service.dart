import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zynkup/features/user/models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // =========================
  // COLLECTION REFERENCES
  // =========================
  CollectionReference get _users => _firestore.collection('users');
  CollectionReference get _events => _firestore.collection('events');

  // =========================
  // CREATE / UPDATE USER PROFILE
  // =========================
  Future<void> createUserProfile(AppUser user) async {
    await _users.doc(user.uid).set(
      user.toFirestore(),
      SetOptions(merge: true), // ✅ safe update
    );
  }

  // =========================
  // USER STREAM
  // =========================
  Stream<AppUser?> getUserStream(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return AppUser.fromFirestore(doc);
    });
  }

  // =========================
  // CHECK ADMIN ROLE
  // =========================
  Future<bool> isAdmin(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.data() != null && doc.get('role') == 'admin';
  }

  // =========================
  // REGISTER USER FOR EVENT
  // =========================
  Future<void> registerForEvent(String userId, String eventId) async {
    final eventRef = _events.doc(eventId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(eventRef);

      if (!snapshot.exists) {
        throw Exception('Event does not exist');
      }

      final List<dynamic> registeredUsers =
          snapshot.get('registeredUsers') ?? [];

      if (registeredUsers.contains(userId)) {
        // Already registered — silently ignore
        return;
      }

      transaction.update(eventRef, {
        'registeredUsers': FieldValue.arrayUnion([userId]),
      });
    });
  }
}
