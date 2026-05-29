import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    "API_BASE_URL",
    defaultValue: "https://zynkup-app.onrender.com",
  );
  static const _storage = FlutterSecureStorage();
  static String? _token;
  static Map<String, dynamic>? _cachedUser;
  static List<dynamic>? _cachedEvents;
  static WebSocketChannel? _wsChannel;
  static final ValueNotifier<Map<String, dynamic>?> latestNotification = ValueNotifier(null);

  static Future<void> initWebSocket() async {
    await loadToken();
    if (_token == null) return;
    final wsUrl = baseUrl.replaceAll('https://', 'wss://').replaceAll('http://', 'ws://');
    final url = Uri.parse("$wsUrl/ws/notifications?token=$_token");
    try {
      _wsChannel?.sink.close();
      _wsChannel = WebSocketChannel.connect(url);
      _wsChannel!.stream.listen((message) {
        try {
          final data = jsonDecode(message);
          latestNotification.value = data;
        } catch (_) {}
      });
    } catch (_) {}
  }

  static void disposeWebSocket() {
    _wsChannel?.sink.close();
    _wsChannel = null;
  }

  static Future<void> loadToken() async {
    _token = await _storage.read(key: "token");
  }

  /// Register FCM token with backend.
  static Future<void> registerFcmToken(String token) async {
    try {
      await loadToken();
      if (!hasToken) return;
      await http.post(
        Uri.parse("$baseUrl/notifications/fcm-token"),
        headers: await _headers,
        body: jsonEncode({"token": token}),
      );
      // ignore response; backend stores token.
    } catch (_) {
      // silently ignore failures – token registration is best‑effort.
    }
  }

  static bool get hasToken => _token != null;

  static Future<void> setToken(String token) async {
    _token = token;
    await _storage.write(key: "token", value: token);
    initWebSocket();
  }

  static Future<void> logout() async {
    _token = null;
    _cachedUser = null;
    _cachedEvents = null;
    disposeWebSocket();
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
      if (!hasToken) return null;
      final res = await http.get(
        Uri.parse("$baseUrl/users/me"),
        headers: await _headers,
      );
      if (res.statusCode == 200) {
        _cachedUser = jsonDecode(res.body) as Map<String, dynamic>;
        return _cachedUser;
      }
      if (res.statusCode == 401 || res.statusCode == 403) await logout();
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
      throw _parseError(res);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException("Image upload failed.");
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
    int? clubId,
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
          if (clubId != null) "club_id": clubId,
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
      if (!hasToken) return [];
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
      if (!hasToken) return [];
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

  static Future<List<Map<String, dynamic>>> uploadEventGallery({
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
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(body['files'] ?? []);
      }
      throw _parseError(res);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException("Gallery upload failed.");
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
      if (!hasToken) return null;
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
      if (!hasToken) return {};
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
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      throw _parseError(res);
    } catch (_) {
      return {};
    }
  }

  // ── Campus Stats ──────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getCampusStats() async {
    try {
      await loadToken();
      final res = await http.get(
        Uri.parse("$baseUrl/analytics/campus-stats"),
        headers: await _headers,
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  // ── Clubs ──────────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getClubs() async {
    try {
      await loadToken();
      final res = await http.get(
        Uri.parse("$baseUrl/clubs/"),
        headers: await _headers,
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as List<dynamic>;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── Feed ───────────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getFeed() async {
    try {
      await loadToken();
      final res = await http.get(
        Uri.parse("$baseUrl/feed/"),
        headers: await _headers,
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as List<dynamic>;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<List<dynamic>> getClubFeed(int clubId) async {
    try {
      await loadToken();
      final res = await http.get(
        Uri.parse("$baseUrl/clubs/$clubId/feed"),
        headers: await _headers,
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as List<dynamic>;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> createFeedPost({
    required String content,
    String? imageUrl,
    String? bannerUrl,
    int? clubId,
  }) async {
    await loadToken();
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/feed/"),
        headers: await _headers,
        body: jsonEncode({
          "content": content,
          if (imageUrl != null) "image_url": imageUrl,
          if (bannerUrl != null) "banner_url": bannerUrl,
          if (clubId != null) "club_id": clubId,
        }),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      throw _parseError(res);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException("Failed to create post.");
    }
  }

  static Future<bool> likeFeedPost(int postId) async {
    try {
      await loadToken();
      final res = await http.post(
        Uri.parse("$baseUrl/feed/$postId/like"),
        headers: await _headers,
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<List<dynamic>> getFeedComments(int postId) async {
    try {
      await loadToken();
      final res = await http.get(
        Uri.parse("$baseUrl/feed/$postId/comments"),
        headers: await _headers,
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as List<dynamic>;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> createFeedComment(
    int postId,
    String content,
  ) async {
    await loadToken();
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/feed/$postId/comments"),
        headers: await _headers,
        body: jsonEncode({"content": content}),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      throw _parseError(res);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException("Failed to create comment.");
    }
  }

  static Future<Map<String, dynamic>> createClub({
    required String name,
    required String description,
    String? category,
    String? bannerUrl,
    String? logoUrl,
  }) async {
    await loadToken();
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/clubs/"),
        headers: await _headers,
        body: jsonEncode({
          "name": name,
          "description": description,
          "category": category ?? "general",
          if (bannerUrl != null) "banner_url": bannerUrl,
          if (logoUrl != null) "logo_url": logoUrl,
        }),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      throw _parseError(res);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException("Failed to create club.");
    }
  }

  static Future<bool> joinClub(int clubId) async {
    try {
      await loadToken();
      final res = await http.post(
        Uri.parse("$baseUrl/clubs/$clubId/join"),
        headers: await _headers,
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> reportFeedPost(int postId) async {
    try {
      await loadToken();
      final res = await http.post(
        Uri.parse("$baseUrl/feed/$postId/report"),
        headers: await _headers,
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteFeedPost(int postId) async {
    try {
      await loadToken();
      final res = await http.delete(
        Uri.parse("$baseUrl/feed/$postId"),
        headers: await _headers,
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> editFeedPost(int postId, {String? content, String? imageUrl}) async {
    try {
      await loadToken();
      final res = await http.patch(
        Uri.parse("$baseUrl/feed/$postId"),
        headers: await _headers,
        body: jsonEncode({
          if (content != null) "content": content,
          if (imageUrl != null) "image_url": imageUrl,
        }),
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Notifications ──────────────────────────────────────────────────────────
  static Future<List<dynamic>> getNotifications() async {
    try {
      await loadToken();
      final res = await http.get(
        Uri.parse("$baseUrl/notifications/"),
        headers: await _headers,
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as List<dynamic>;
      }
      return [];
    } catch (_) {
      return [];
    }
  }
  // ── Timeline ────────────────────────────────────────────────────────────────



  // ── Mark all notifications read ──────────────────────────────────────────────

  /// Mark all notifications as read.
  static Future<bool> markAllRead() async {
    try {
      await loadToken();
      final res = await http.post(
        Uri.parse("$baseUrl/notifications/mark-all-read"),
        headers: await _headers,
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }




  static Future<bool> markNotificationRead(int notifId) async {
    try {
      await loadToken();
      final res = await http.post(
        Uri.parse("$baseUrl/notifications/$notifId/read"),
        headers: await _headers,
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }



  static Future<int> getUnreadNotificationCount() async {
    try {
      await loadToken();
      if (!hasToken) return 0;
      final res = await http.get(
        Uri.parse("$baseUrl/notifications/unread-count"),
        headers: await _headers,
      );
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as Map<String, dynamic>)['count'] as int? ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  // ── Extended Clubs ─────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getClubById(int clubId) async {
    try {
      await loadToken();
      final res = await http.get(
        Uri.parse("$baseUrl/clubs/$clubId"),
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

  static Future<List<dynamic>> getClubMembers(int clubId) async {
    try {
      await loadToken();
      final res = await http.get(
        Uri.parse("$baseUrl/clubs/$clubId/members"),
        headers: await _headers,
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as List<dynamic>;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<bool> updateClubMemberRole(int clubId, int userId, String role) async {
    try {
      await loadToken();
      final res = await http.put(
        Uri.parse("$baseUrl/clubs/$clubId/members/$userId/role"),
        headers: await _headers,
        body: jsonEncode({"role": role}),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<List<dynamic>> getClubEvents(int clubId) async {
    try {
      await loadToken();
      final res = await http.get(
        Uri.parse("$baseUrl/clubs/$clubId/events"),
        headers: await _headers,
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as List<dynamic>;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<List<dynamic>> getClubGallery(int clubId) async {
    try {
      await loadToken();
      final res = await http.get(
        Uri.parse("$baseUrl/clubs/$clubId/gallery"),
        headers: await _headers,
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return body['files'] as List<dynamic>? ?? [];
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>?> uploadClubGallery(
    int clubId,
    Uint8List fileBytes,
    String filename,
  ) async {
    try {
      await loadToken();
      final req = http.MultipartRequest(
        'POST',
        Uri.parse("$baseUrl/clubs/$clubId/gallery"),
      );
      if (_token != null) req.headers['Authorization'] = 'Bearer $_token';

      final ext = filename.split('.').last.toLowerCase();
      String mime = 'image/jpeg';
      if (ext == 'png') mime = 'image/png';
      if (ext == 'webp') mime = 'image/webp';

      req.files.add(
        http.MultipartFile.fromBytes(
          'files',
          fileBytes,
          filename: filename,
          contentType: MediaType.parse(mime),
        ),
      );

      final res = await http.Response.fromStream(await req.send());
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      throw _parseError(res);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException("Club gallery upload failed.");
    }
  }

  static Future<List<dynamic>> getTimeline() async {
    try {
      await loadToken();
      final res = await http.get(
        Uri.parse("$baseUrl/users/me/timeline"),
        headers: await _headers,
      );
      if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
      return [];
    } catch (_) {
      return [];
    }
  }



  static Future<bool> reactToFeedPost(int postId, String emoji) async {
    try {
      await loadToken();
      final res = await http.post(
        Uri.parse("$baseUrl/feed/$postId/react"),
        headers: await _headers,
        body: jsonEncode({"emoji": emoji}),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> votePoll(int postId, int optionIndex) async {
    try {
      await loadToken();
      final res = await http.post(
        Uri.parse("$baseUrl/feed/$postId/poll/vote"),
        headers: await _headers,
        body: jsonEncode({"option_index": optionIndex}),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

