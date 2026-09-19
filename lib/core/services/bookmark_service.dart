import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zynkup/features/events/models/event_model.dart';

class BookmarkService {
  static const String _eventsKey = 'zynkup_bookmarked_events';
  static const String _postsKey = 'zynkup_bookmarked_posts';

  static final ValueNotifier<int> bookmarkUpdateNotifier = ValueNotifier<int>(0);

  static Set<String>? _cachedEventIds;
  static Set<int>? _cachedPostIds;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final eventsRaw = prefs.getString(_eventsKey);
    if (eventsRaw != null) {
      try {
        final List<dynamic> list = jsonDecode(eventsRaw);
        _cachedEventIds = list
            .map((e) => e is Map ? (e['id']?.toString() ?? '') : '')
            .where((id) => id.isNotEmpty)
            .toSet();
      } catch (_) {
        _cachedEventIds = {};
      }
    } else {
      _cachedEventIds = {};
    }

    final postsRaw = prefs.getString(_postsKey);
    if (postsRaw != null) {
      try {
        final List<dynamic> list = jsonDecode(postsRaw);
        _cachedPostIds = list
            .map((p) => p is Map ? (int.tryParse(p['id']?.toString() ?? '') ?? 0) : 0)
            .where((id) => id > 0)
            .toSet();
      } catch (_) {
        _cachedPostIds = {};
      }
    } else {
      _cachedPostIds = {};
    }
  }

  // ─── Event Bookmarks ────────────────────────────────────────────────────────

  static bool isEventBookmarkedSync(String eventId) {
    return _cachedEventIds?.contains(eventId) ?? false;
  }

  static Future<bool> isEventBookmarked(String eventId) async {
    if (_cachedEventIds == null) await init();
    return _cachedEventIds!.contains(eventId);
  }

  static Future<bool> toggleEventBookmark(Event event) async {
    if (_cachedEventIds == null) await init();
    final prefs = await SharedPreferences.getInstance();
    final events = await getBookmarkedEvents();
    final exists = events.any((e) => e.id == event.id);

    if (exists) {
      events.removeWhere((e) => e.id == event.id);
      _cachedEventIds!.remove(event.id);
    } else {
      events.insert(0, event);
      _cachedEventIds!.add(event.id);
    }

    final encoded = jsonEncode(events.map((e) => e.toJson()).toList());
    await prefs.setString(_eventsKey, encoded);
    bookmarkUpdateNotifier.value++;
    return !exists;
  }

  static Future<List<Event>> getBookmarkedEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_eventsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list.map((item) => Event.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> removeEventBookmark(String eventId) async {
    if (_cachedEventIds == null) await init();
    final prefs = await SharedPreferences.getInstance();
    final events = await getBookmarkedEvents();
    events.removeWhere((e) => e.id == eventId);
    _cachedEventIds!.remove(eventId);
    await prefs.setString(_eventsKey, jsonEncode(events.map((e) => e.toJson()).toList()));
    bookmarkUpdateNotifier.value++;
  }

  // ─── Feed Post Bookmarks ───────────────────────────────────────────────────

  static bool isPostBookmarkedSync(dynamic postId) {
    final id = int.tryParse(postId?.toString() ?? '') ?? 0;
    return _cachedPostIds?.contains(id) ?? false;
  }

  static Future<bool> isPostBookmarked(dynamic postId) async {
    if (_cachedPostIds == null) await init();
    final id = int.tryParse(postId?.toString() ?? '') ?? 0;
    return _cachedPostIds!.contains(id);
  }

  static Future<bool> togglePostBookmark(Map<String, dynamic> post) async {
    if (_cachedPostIds == null) await init();
    final id = int.tryParse(post['id']?.toString() ?? '') ?? 0;
    if (id == 0) return false;

    final prefs = await SharedPreferences.getInstance();
    final posts = await getBookmarkedPosts();
    final exists = posts.any((p) => (int.tryParse(p['id']?.toString() ?? '') ?? 0) == id);

    if (exists) {
      posts.removeWhere((p) => (int.tryParse(p['id']?.toString() ?? '') ?? 0) == id);
      _cachedPostIds!.remove(id);
    } else {
      posts.insert(0, Map<String, dynamic>.from(post));
      _cachedPostIds!.add(id);
    }

    await prefs.setString(_postsKey, jsonEncode(posts));
    bookmarkUpdateNotifier.value++;
    return !exists;
  }

  static Future<List<Map<String, dynamic>>> getBookmarkedPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_postsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> removePostBookmark(dynamic postId) async {
    if (_cachedPostIds == null) await init();
    final id = int.tryParse(postId?.toString() ?? '') ?? 0;
    final prefs = await SharedPreferences.getInstance();
    final posts = await getBookmarkedPosts();
    posts.removeWhere((p) => (int.tryParse(p['id']?.toString() ?? '') ?? 0) == id);
    _cachedPostIds!.remove(id);
    await prefs.setString(_postsKey, jsonEncode(posts));
    bookmarkUpdateNotifier.value++;
  }
}
