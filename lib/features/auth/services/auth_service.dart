import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthService {
  static const String baseUrl = "http://127.0.0.1:8000";

  /// 🔐 TOKEN (temporary - later secure storage)
  String? _token;

  /// ================= SIGNUP =================
  Future<bool> signUp(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/users/signup"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "password": password,
        }),
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
        body: jsonEncode({
          "email": email,
          "password": password,
        }),
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
        headers: {
          "Authorization": "Bearer $_token",
        },
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
        body: jsonEncode({
          "token": fcmToken,
        }),
      );
    } catch (_) {}
  }

  /// ================= LOGOUT =================
  Future<void> signOut() async {
    _token = null;
  }

  /// ================= CHECK LOGIN =================
  bool get isLoggedIn => _token != null;
}