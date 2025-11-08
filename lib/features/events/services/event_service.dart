import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:zynkup/features/events/models/event_model.dart';

class EventService {
  final CollectionReference _events;

  EventService()
      : _events = FirebaseFirestore.instance.collection('events') {
    // Web-specific Firestore settings
    if (kIsWeb) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
        sslEnabled: true,
      );
    }
  }

  // Get all events (latest first)
  Stream<List<Event>> getEvents() {
    return _events
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Event.fromFirestore(d)).toList());
  }

  // Get events by category (latest first)
  Stream<List<Event>> getEventsByCategory(EventCategory category) {
    return _events
        .where('category', isEqualTo: category.name)
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Event.fromFirestore(d)).toList());
  }

  // Create event
  Future<String> createEvent(Event event) async {
    try {
      final docRef = await _events.add(event.toFirestore());
      await docRef.update({'id': docRef.id});
      return docRef.id;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception('Permission denied. Check Firestore rules.');
      }
      rethrow;
    }
  }

  // Update event
  Future<void> updateEvent(Event event) async {
    try {
      await _events.doc(event.id).set(event.toFirestore(), SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception('Only the organizer can edit this event.');
      }
      rethrow;
    }
  }

  // Delete event
  Future<void> deleteEvent(String eventId) async {
    try {
      await _events.doc(eventId).delete();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception('Only the organizer can delete this event.');
      }
      rethrow;
    }
  }

  // Register user
  Future<void> registerUser(String eventId, String userId) async {
    try {
      await _events.doc(eventId).update({
        'registeredUsers': FieldValue.arrayUnion([userId])
      });
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') {
        throw Exception('Event not found.');
      }
      rethrow;
    }
  }

  // Unregister user
  Future<void> unregisterUser(String eventId, String userId) async {
    try {
      await _events.doc(eventId).update({
        'registeredUsers': FieldValue.arrayRemove([userId])
      });
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') {
        throw Exception('Event not found.');
      }
      rethrow;
    }
  }
}