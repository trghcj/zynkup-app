import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'package:zynkup/features/events/models/event_model.dart';
import 'package:zynkup/features/events/screens/event_details_screen.dart';

enum EventFilter { all, today, upcoming, past }

class EventListWidget extends StatefulWidget {
  const EventListWidget({super.key});

  @override
  State<EventListWidget> createState() => _EventListWidgetState();
}

class _EventListWidgetState extends State<EventListWidget> {
  EventFilter _selectedFilter = EventFilter.all;

  List<Event> _events = [];
  bool _isLoading = true;

  final String baseUrl = "http://127.0.0.1:8000";

  @override
  void initState() {
    super.initState();
    fetchEvents();
  }

  /// 🔥 FETCH EVENTS FROM API
  Future<void> fetchEvents() async {
    try {
      final res = await http.get(Uri.parse("$baseUrl/events"));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        setState(() {
          _events = (data as List)
              .map((e) => Event.fromJson(e))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final events = _applyFilter(_events);

    if (events.isEmpty) return _emptyState();

    return Column(
      children: [
        _filterDropdown(),

        Expanded(
          child: RefreshIndicator(
            onRefresh: fetchEvents,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: events.length,
              itemBuilder: (_, i) {
                final event = events[i];
                final isUpcoming =
                    event.date.isAfter(DateTime.now());

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),

                    /// 🖼 IMAGE
                    leading: event.imageUrls.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              event.imageUrls.first,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(Icons.event, size: 40),

                    /// 📝 TITLE
                    title: Text(
                      event.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold),
                    ),

                    /// 📍 DETAILS
                    subtitle: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(event.venue),
                        Text(
                          DateFormat('MMM dd • hh:mm a')
                              .format(event.date),
                        ),
                      ],
                    ),

                    /// 🟢 STATUS
                    trailing: isUpcoming
                        ? const Chip(
                            label: Text("Upcoming"),
                            backgroundColor: Colors.green,
                          )
                        : const Chip(
                            label: Text("Past"),
                            backgroundColor: Colors.grey,
                          ),

                    /// 🔗 NAVIGATION
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              EventDetailsScreen(event: event),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// 🔽 FILTER
  List<Event> _applyFilter(List<Event> events) {
    final now = DateTime.now();

    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfToday = startOfToday.add(const Duration(days: 1));

    return events.where((event) {
      /// 🔐 ONLY SHOW APPROVED EVENTS
      if (!event.isApproved) return false;

      switch (_selectedFilter) {
        case EventFilter.today:
          return event.date.isAfter(startOfToday) &&
              event.date.isBefore(endOfToday);

        case EventFilter.upcoming:
          return event.date.isAfter(now);

        case EventFilter.past:
          return event.date.isBefore(now);

        case EventFilter.all:
          return true;
      }
    }).toList();
  }

  /// 🎛 FILTER UI
  Widget _filterDropdown() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: DropdownButtonFormField<EventFilter>(
        value: _selectedFilter,
        decoration: const InputDecoration(
          labelText: "Filter Events",
          border: OutlineInputBorder(),
        ),
        items: EventFilter.values
            .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e.name.toUpperCase()),
                ))
            .toList(),
        onChanged: (v) => setState(() => _selectedFilter = v!),
      ),
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Text("No events found 📭"),
    );
  }
}