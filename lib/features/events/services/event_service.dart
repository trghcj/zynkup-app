import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zynkup/features/events/models/event_model.dart';

class EventService {
  final CollectionReference _events = FirebaseFirestore.instance.collection('events');

  // Get all events, sorted by date descending
  Stream<List<Event>> getEvents() {
    return _events.orderBy('date', descending: true).snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList(),
        );
  }

  // Get events by category
  Stream<List<Event>> getEventsByCategory(EventCategory category) {
    return _events
        .where('category', isEqualTo: category.toString().split('.').last)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList(),
        );
  }

  // Create new event (for organizers)
  Future<String> createEvent(Event event) async {
    final docRef = await _events.add(event.toFirestore());
    return docRef.id;
  }

  // More methods like updateEvent, registerUser later
}