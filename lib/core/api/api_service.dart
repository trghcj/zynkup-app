import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ── Custom exception ──────────────────────────────────────────────────────────
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

// ── ApiService ────────────────────────────────────────────────────────────────
class ApiService {
  static const String baseUrl = "https://zynkup-app.onrender.com";

  static const _storage = FlutterSecureStorage();
  static String? _token;
  static Map<String, dynamic>? _cachedUser;
  static List<dynamic>? _cachedEvents;

  // ── Token ──────────────────────────────────────────────────────────────────
  static Future<void> loadToken() async {
    _token = await _storage.read(key: "token");
  }

  static bool get hasToken => _token != null;

  static Future<void> setToken(String token) async {
    _token = token;
    await _storage.write(key: "token", value: token);
  }

  static Future<void> logout() async {
    _token = null;
    _cachedUser = null;
    _cachedEvents = null;
    await _storage.delete(key: "token");
  }

  // ── Headers ────────────────────────────────────────────────────────────────
  // Async version — always reads fresh token from storage
  static Future<Map<String, String>> get _headers async {
    final token = await _storage.read(key: "token");
    return {
      "Content-Type": "application/json",
      if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
    };
  }

  // Sync version for multipart requests — uses cached _token
  static Map<String, String> get authHeaders => {
    "Content-Type": "application/json",
    if (_token != null && _token!.isNotEmpty) "Authorization": "Bearer $_token",
  };

  // Auth-only headers (no Content-Type) for multipart requests
  static Map<String, String> get authOnlyHeaders => {
    if (_token != null && _token!.isNotEmpty) "Authorization": "Bearer $_token",
  };

  // ── Error parser ───────────────────────────────────────────────────────────
  static ApiException _parseError(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      final msg = body["detail"] ?? "Error (${res.statusCode})";
      return ApiException(msg.toString(), res.statusCode);
    } catch (_) {
      return ApiException("Unexpected error (${res.statusCode})", res.statusCode);
    }
  }

  // ── Signup ─────────────────────────────────────────────────────────────────
  static Future<bool> signUp(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/users/signup"),
        headers: await _headers,
        body: jsonEncode({"email": email, "password": password}),
      );
      if (res.statusCode == 200 || res.statusCode == 201) return true;
      throw _parseError(res);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException("Network error. Is the server running?");
    }
  }

  // ── Login ──────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/users/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        await setToken(data["access_token"] as String);
        await loadToken();
        _cachedUser = null;
        return data;
      }
      throw _parseError(res);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException("Network error. Is the server running?");
    }
  }

  // ── Get current user ───────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getCurrentUser(
      {bool force = false}) async {
    if (!force && _cachedUser != null) return _cachedUser;
    try {
      await loadToken();
      final res = await http.get(
        Uri.parse("$baseUrl/users/me"),
        headers: await _headers,
      );
      if (res.statusCode == 200) {
        _cachedUser = jsonDecode(res.body) as Map<String, dynamic>;
        return _cachedUser;
      }
      if (res.statusCode == 401) await logout();
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Create / update profile ────────────────────────────────────────────────
  static Future<bool> createProfile({
    required String name,
    String? displayName,
    String? phone,
    String? branch,
    String? year,
    String? enrollment,
    String? college,
    String? bio,
    String? avatarUrl,
  }) async {
    try {
      await loadToken();
      final res = await http.post(
        Uri.parse("$baseUrl/users/create-profile"),
        headers: await _headers,
        body: jsonEncode({
          "name": name,
          if (displayName != null) "display_name": displayName,
          if (phone != null) "phone": phone,
          if (branch != null) "branch": branch,
          if (year != null) "year": year,
          if (enrollment != null) "enrollment": enrollment,
          if (college != null) "college": college,
          if (bio != null) "bio": bio,
          if (avatarUrl != null) "avatar_url": avatarUrl,
        }),
      );
      if (res.statusCode == 200) {
        _cachedUser = null;
        return true;
      }
      throw _parseError(res);
    } on ApiException {
      rethrow;
    } catch (_) {
      return false;
    }
  }

  // ── Upload image bytes (multipart) ─────────────────────────────────────────
  static Future<String?> uploadImageBytes(
      Uint8List bytes, String filename) async {
    try {
      await loadToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse("$baseUrl/upload"),
      );
      if (_token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
      ));
      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['url'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Upload gallery files for event (admin only) ────────────────────────────
  static Future<bool> uploadEventGallery({
    required int eventId,
    required List<Uint8List> files,
    required List<String> filenames,
  }) async {
    try {
      await loadToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse("$baseUrl/events/$eventId/gallery"),
      );
      if (_token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }
      for (int i = 0; i < files.length; i++) {
        request.files.add(http.MultipartFile.fromBytes(
          'files',
          files[i],
          filename: filenames[i],
        ));
      }
      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Fetch gallery files for an event (returns full file map list) ──────────
  // Used by EventGalleryScreen to get [{name, mime, data}, ...] from the server.
  static Future<List<Map<String, dynamic>>> fetchGalleryFiles(
      int eventId) async {
    try {
      await loadToken();
      final res = await http.get(
        Uri.parse("$baseUrl/events/$eventId/gallery"),
        headers: await _headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return List<Map<String, dynamic>>.from(data['files'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── Get event gallery (returns list of base64 strings, legacy) ────────────
  static Future<List<String>> getEventGallery(int eventId) async {
    try {
      await loadToken();
      final res = await http.get(
        Uri.parse("$baseUrl/events/$eventId/gallery"),
        headers: await _headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return List<String>.from(data["gallery"] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── Get single event by ID ────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getEventById(int eventId) async {
    try {
      await loadToken();
      final res = await http.get(
        Uri.parse("$baseUrl/events/$eventId"),
        headers: await _headers,
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Get events ─────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getEvents(
      {bool force = false, int skip = 0, int limit = 20}) async {
    if (!force && _cachedEvents != null && skip == 0) return _cachedEvents!;
    try {
      await loadToken();
      final res = await http.get(
        Uri.parse("$baseUrl/events/?skip=$skip&limit=$limit"),
        headers: await _headers,
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        if (skip == 0) _cachedEvents = list;
        return list;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── Create event ───────────────────────────────────────────────────────────
  static Future<bool> createEvent({
    required String title,
    required String description,
    required String venue,
    required String date,
    required String category,
    List<String>? imageUrls,
    String? registrationUrl,
    String? registrationUrlType,
  }) async {
    await loadToken();
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/events/"),
        headers: await _headers,
        body: jsonEncode({
          "title": title,
          "description": description,
          "venue": venue,
          "date": date,
          "category": category,
          // FIX: send as List, not a comma-joined String.
          // imageUrls.join(",") was causing 422 — backend expects List[str].
          if (imageUrls != null && imageUrls.isNotEmpty)
            "image_urls": imageUrls,
          if (registrationUrl != null) "registration_url": registrationUrl,
          if (registrationUrlType != null)
            "registration_url_type": registrationUrlType,
        }),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        _cachedEvents = null;
        return true;
      }
      throw _parseError(res);
    } on ApiException {
      rethrow;
    } catch (_) {
      return false;
    }
  }

  // ── Register for event ─────────────────────────────────────────────────────
  static Future<bool> registerEvent(int eventId) async {
    try {
      await loadToken();
      final res = await http.post(
        Uri.parse("$baseUrl/events/$eventId/register"),
        headers: await _headers,
      );
      if (res.statusCode == 200) return true;
      throw _parseError(res);
    } on ApiException {
      rethrow;
    } catch (_) {
      return false;
    }
  }

  // ── My events ──────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getMyEvents() async {
    try {
      await loadToken();
      final res = await http.get(
        Uri.parse("$baseUrl/users/my-events"),
        headers: await _headers,
      );
      if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── All users (admin) ──────────────────────────────────────────────────────
  static Future<List<dynamic>> getAllUsers() async {
    try {
      await loadToken();
      final res = await http.get(
        Uri.parse("$baseUrl/users/all"),
        headers: await _headers,
      );
      if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── Admin: pending events ──────────────────────────────────────────────────
  static Future<List<dynamic>> getPendingEvents() async {
    try {
      await loadToken();
      final res = await http.get(
        Uri.parse("$baseUrl/admin/events/pending"),
        headers: await _headers,
      );
      if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── Admin: approve event ───────────────────────────────────────────────────
  static Future<bool> approveEvent(int eventId) async {
    try {
      await loadToken();
      final res = await http.put(
        Uri.parse("$baseUrl/admin/approve/$eventId"),
        headers: await _headers,
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Admin: reject / delete event ──────────────────────────────────────────
  static Future<bool> rejectEvent(int eventId) async {
    try {
      await loadToken();
      final res = await http.delete(
        Uri.parse("$baseUrl/admin/reject/$eventId"),
        headers: await _headers,
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Admin: delete event (by event id directly) ─────────────────────────────
  static Future<bool> deleteEvent(int eventId) async {
    try {
      await loadToken();
      final res = await http.delete(
        Uri.parse("$baseUrl/events/$eventId"),
        headers: await _headers,
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Admin: delete past events ──────────────────────────────────────────────
  static Future<bool> deletePastEvents() async {
    try {
      await loadToken();
      final res = await http.delete(
        Uri.parse("$baseUrl/admin/delete-past-events"),
        headers: await _headers,
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Admin: set user role ───────────────────────────────────────────────────
  static Future<bool> setUserRole(int userId, String role) async {
    try {
      await loadToken();
      final res = await http.put(
        Uri.parse("$baseUrl/admin/set-role/$userId?role=$role"),
        headers: await _headers,
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Admin: make admin by email ─────────────────────────────────────────────
  static Future<bool> makeAdminByEmail(String email) async {
    try {
      await loadToken();
      final res = await http.put(
        Uri.parse("$baseUrl/admin/make-admin/$email"),
        headers: await _headers,
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Analytics ──────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getAnalytics() async {
    try {
      await loadToken();
      final res = await http.get(
        Uri.parse("$baseUrl/analytics/"),
        headers: await _headers,
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}