import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zynkup/features/user/models/user_model.dart';

class UserService {
  final CollectionReference _users = FirebaseFirestore.instance.collection('users');

  Future<void> createUserProfile(AppUser user) async {
    await _users.doc(user.uid).set(user.toFirestore());
  }

  Stream<AppUser?> getUserStream(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (doc.exists) return AppUser.fromFirestore(doc);
      return null;
    });
  }

  Future<void> registerForEvent(String userId, String id) async {}
}