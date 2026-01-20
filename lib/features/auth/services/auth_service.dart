import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '659234851207-o80f3633j9f09j79d0ml7376o7v4iv58.apps.googleusercontent.com'
        : null,
  );

  // =========================
  // EMAIL LOGIN
  // =========================
  Future<User?> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _createUserIfNotExists(credential.user!);
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseError(e);
    }
  }

  // =========================
  // EMAIL SIGN UP
  // =========================
  Future<User?> signUp(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _createUserIfNotExists(credential.user!);
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseError(e);
    }
  }

  // =========================
  // GOOGLE SIGN-IN
  // =========================
  Future<User?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw 'Google Sign-In cancelled';

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await _auth.signInWithCredential(credential);

      await _createUserIfNotExists(userCredential.user!);
      return userCredential.user;
    } catch (e) {
      throw 'Google Sign-In failed';
    }
  }

  // =========================
  // CREATE USER IN FIRESTORE
  // =========================
  Future<void> _createUserIfNotExists(User user) async {
    final ref = _firestore.collection('users').doc(user.uid);
    final doc = await ref.get();

    if (!doc.exists) {
      await ref.set({
        'email': user.email,
        'role': 'user', // 👈 DEFAULT ROLE
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // =========================
  // SIGN OUT
  // =========================
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;

  // =========================
  // ERROR MAPPER
  // =========================
  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-email':
        return 'Invalid email';
      case 'email-already-in-use':
        return 'Email already registered';
      case 'weak-password':
        return 'Weak password';
      default:
        return e.message ?? 'Auth failed';
    }
  }
}
