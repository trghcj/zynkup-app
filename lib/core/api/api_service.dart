import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

class ApiService {
  static const String baseUrl = "https://zynkup-app.onrender.com";
  static const _storage = FlutterSecureStorage();
  static String? _token;
  static Map<String, dynamic>? _cachedUser;
  static List<dynamic>? _cachedEvents;

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

  static Future<Map<String, String>> get _headers async {
    final token = await _storage.read(key: "token");
    return {
      "Content-Type": "application/json",
      if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
    };
  }

  static ApiException _parseError(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      final msg = body["detail"] ?? "Error (${res.statusCode})";
      return ApiException(msg.toString(), res.statusCode);
    } catch (_) {
      return ApiException(
        "Unexpected error (${res.statusCode})",
        res.statusCode,
      );
    }
  }

  // ── Auth ───────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> signUp(
    String email,
    String password,
  ) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/users/signup"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data["access_token"] != null) {
          await setToken(data["access_token"] as String);
          _cachedUser = null;
        }
        return data;
      }
      throw _parseError(res);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException("Network error. Is the server running?");
    }
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/users/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        await setToken(data["access_token"] as String);
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

  /// Send Firebase Google ID token → backend returns JWT
  static Future<Map<String, dynamic>> googleLogin(String idToken) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/users/google"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id_token": idToken}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        await setToken(data["access_token"] as String);
        _cachedUser = null;
        return data;
      }
      throw _parseError(res);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException("Google sign-in failed.");
    }
  }

  // ── User ───────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getCurrentUser({
    bool force = false,
  }) async {
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

  static Future<bool> updateProfile({
    String? name,
    String? displayName,
    String? phone,
    String? branch,
    String? year,
    String? enrollment,
    String? college,
    String? bio,
    String? avatarUrl,
    String? avatarSeed,
    String? avatarType,
    String? theme,
  }) async {
    try {
      await loadToken();
      final res = await http.put(
        Uri.parse("$baseUrl/users/me"),
        headers: await _headers,
        body: jsonEncode({
          if (name != null) "name": name,
          if (displayName != null) "display_name": displayName,
          if (phone != null) "phone": phone,
          if (branch != null) "branch": branch,
          if (year != null) "year": year,
          if (enrollment != null) "enrollment": enrollment,
          if (college != null) "college": college,
          if (bio != null) "bio": bio,
          if (avatarUrl != null) "avatar_url": avatarUrl,
          if (avatarSeed != null) "avatar_seed": avatarSeed,
          if (avatarType != null) "avatar_type": avatarType,
          if (theme != null) "theme": theme,
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

  // Legacy compat
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
  }) => updateProfile(
    name: name,
    displayName: displayName,
    phone: phone,
    branch: branch,
    year: year,
    enrollment: enrollment,
    college: college,
    bio: bio,
    avatarUrl: avatarUrl,
  );

  // ── Upload ─────────────────────────────────────────────────────────────────

  static Future<String?> uploadImageBytes(
    Uint8List bytes,
    String filename,
  ) async {
    try {
      await loadToken();
      final req = http.MultipartRequest('POST', Uri.parse("$baseUrl/upload"));
      if (_token != null) req.headers['Authorization'] = 'Bearer $_token';
      req.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );
      final res = await http.Response.fromStream(await req.send());
      if (res.statusCode == 200) {
        return (jsonDecode(res.body))['url'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Events ─────────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getEvents({
    bool force = false,
    int skip = 0,
    int limit = 20,
  }) async {
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

  /// Returns full event dict on success (including id for navigation)
  static Future<Map<String, dynamic>> createEvent({
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
          if (imageUrls != null && imageUrls.isNotEmpty)
            "image_urls": imageUrls,
          if (registrationUrl != null) "registration_url": registrationUrl,
          if (registrationUrlType != null)
            "registration_url_type": registrationUrlType,
        }),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        _cachedEvents = null;
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      throw _parseError(res);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException("Failed to create event.");
    }
  }

  static Future<bool> deleteEvent(int eventId) async {
    try {
      await loadToken();
      final res = await http.delete(
        Uri.parse("$baseUrl/events/$eventId"),
        headers: await _headers,
      );
      if (res.statusCode == 200) {
        _cachedEvents = null;
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── Registration ───────────────────────────────────────────────────────────

  /// Returns {qr_code, message} on success
  static Future<Map<String, dynamic>> registerEvent(int eventId) async {
    try {
      await loadToken();
      final res = await http.post(
        Uri.parse("$baseUrl/events/$eventId/register"),
        headers: await _headers,
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      throw _parseError(res);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException("Registration failed.");
    }
  }

  /// Returns [{qr_code, attended, registered_at, event}, ...]
  static Future<List<dynamic>> getMyRegistrations() async {
    try {
      await loadToken();
      final res = await http.get(
        Uri.parse("$baseUrl/users/my-registrations"),
        headers: await _headers,
      );
      if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
      return [];
    } catch (_) {
      return [];
    }
  }

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

  // ── QR Attendance (creator scans attendee QR) ──────────────────────────────

  static Future<Map<String, dynamic>> markAttendance(String qrCode) async {
    try {
      await loadToken();
      final res = await http.post(
        Uri.parse("$baseUrl/events/attendance/$qrCode"),
        headers: await _headers,
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      throw _parseError(res);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException("Failed to mark attendance.");
    }
  }

  // ── Gallery ────────────────────────────────────────────────────────────────

  static Future<bool> uploadEventGallery({
    required int eventId,
    required List<Uint8List> files,
    required List<String> filenames,
  }) async {
    try {
      await loadToken();
      final req = http.MultipartRequest(
        'POST',
        Uri.parse("$baseUrl/events/$eventId/gallery"),
      );
      if (_token != null) req.headers['Authorization'] = 'Bearer $_token';
      for (int i = 0; i < files.length; i++) {
        final filename = filenames[i].toLowerCase();
        String mime = 'image/jpeg';
        if (filename.endsWith('.png')) mime = 'image/png';
        if (filename.endsWith('.webp')) mime = 'image/webp';
        if (filename.endsWith('.pdf')) mime = 'application/pdf';

        req.files.add(
          http.MultipartFile.fromBytes(
            'files',
            files[i],
            filename: filenames[i],
            contentType: MediaType.parse(mime),
          ),
        );
      }
      final res = await http.Response.fromStream(await req.send());
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchGalleryFiles(
    int eventId,
  ) async {
    try {
      await loadToken();
      final res = await http.get(
        Uri.parse("$baseUrl/events/$eventId/gallery"),
        headers: await _headers,
      );
      if (res.statusCode == 200) {
        return List<Map<String, dynamic>>.from(
          jsonDecode(res.body)['files'] ?? [],
        );
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── Analytics (personal) ───────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getPersonalAnalytics() async {
    try {
      await loadToken();
      final res = await http.get(
        Uri.parse("$baseUrl/analytics/me"),
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

  static Future<Map<String, dynamic>?> getAnalytics() => getPersonalAnalytics();

  static Future<Map<String, int>> getHeatmapData() async {
    try {
      await loadToken();
      final res = await http.get(
        Uri.parse("$baseUrl/analytics/heatmap"),
        headers: await _headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data.map((key, value) => MapEntry(key, value as int));
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  static Future<Map<String, dynamic>> getGamificationDetails() async {
    try {
      await loadToken();
      final res = await http.get(
        Uri.parse("$baseUrl/users/me/gamification"),
        headers: await _headers,
      );
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
      throw _parseError(res);
    } catch (_) {
      return {};
    }
  }
}
