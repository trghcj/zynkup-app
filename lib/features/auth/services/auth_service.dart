import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static const String baseUrl = "http://127.0.0.1:8000";

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// 🔐 TOKEN (temporary - later secure storage)
  String? _token;

  /// ================= SIGNUP =================
  Future<bool> signUp(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/users/signup"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );

      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  /// ================= LOGIN =================
  Future<bool> signIn(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/users/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _token = data["access_token"];

        /// 🔥 SAVE FCM TOKEN TO BACKEND
        await _saveFcmToken();

        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// ================= GET CURRENT USER =================
  Future<Map<String, dynamic>?> getCurrentUser() async {
    if (_token == null) return null;

    try {
      final res = await http.get(
        Uri.parse("$baseUrl/users/me"),
        headers: {"Authorization": "Bearer $_token"},
      );

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// ================= SAVE FCM TOKEN =================
  Future<void> _saveFcmToken() async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();

      if (fcmToken == null || _token == null) return;

      await http.post(
        Uri.parse("$baseUrl/users/save-token"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $_token",
        },
        body: jsonEncode({"token": fcmToken}),
      );
    } catch (_) {}
  }

  /// ================= LOGOUT =================
  Future<void> signOut() async {
    _token = null;
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  /// ================= CHECK LOGIN =================
  bool get isLoggedIn => _token != null;

  /// ================= GOOGLE SIGN IN =================
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      // --- Backend Integration ---
      final idToken = googleAuth.idToken;
      if (idToken != null) {
        final res = await http.post(
          Uri.parse("$baseUrl/users/google"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"id_token": idToken}),
        );

        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = jsonDecode(res.body);
          _token = data["access_token"];

          /// 🔥 SAVE FCM TOKEN TO BACKEND
          await _saveFcmToken();
        } else {
          // If backend authentication fails, sign out from Firebase and Google
          await _auth.signOut();
          await _googleSignIn.signOut();
          return null;
        }
      }

      return userCredential;
    } catch (e) {
      return null;
    }
  }
}
