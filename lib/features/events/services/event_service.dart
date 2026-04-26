import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:zynkup/features/events/models/event_model.dart';

class EventService {
  final String baseUrl = "http://127.0.0.1:8000";

  /// 🔥 GET ALL EVENTS
  Future<List<Event>> getEvents() async {
    final res = await http.get(Uri.parse("$baseUrl/events"));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return (data as List)
          .map((e) => Event.fromJson(e))
          .toList();
    } else {
      throw Exception("Failed to load events");
    }
  }

  /// 🔥 GET EVENTS BY CATEGORY
  Future<List<Event>> getEventsByCategory(EventCategory category) async {
    final res = await http.get(
      Uri.parse("$baseUrl/events?category=${category.name}"),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return (data as List)
          .map((e) => Event.fromJson(e))
          .toList();
    } else {
      throw Exception("Failed to load category events");
    }
  }

  /// 🔥 CREATE EVENT
  Future<String> createEvent(Event event) async {
    final res = await http.post(
      Uri.parse("$baseUrl/events"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(event.toJson()),
    );

    if (res.statusCode == 201 || res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data["id"].toString();
    } else {
      throw Exception("Failed to create event");
    }
  }

  /// 🔥 UPDATE EVENT
  Future<void> updateEvent(Event event) async {
    final res = await http.put(
      Uri.parse("$baseUrl/events/${event.id}"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(event.toJson()),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to update event");
    }
  }

  /// 🔥 DELETE EVENT
  Future<void> deleteEvent(String eventId) async {
    final res = await http.delete(
      Uri.parse("$baseUrl/events/$eventId"),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to delete event");
    }
  }

  /// 🔥 REGISTER USER
  Future<void> registerUser(String eventId) async {
    final res = await http.post(
      Uri.parse("$baseUrl/events/$eventId/register"),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to register");
    }
  }

  /// 🔥 UNREGISTER USER
  Future<void> unregisterUser(String eventId) async {
    final res = await http.post(
      Uri.parse("$baseUrl/events/$eventId/unregister"),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to unregister");
    }
  }
}